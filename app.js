import * as THREE from "https://unpkg.com/three@0.160.0/build/three.module.js";
import { GLTFLoader } from "https://unpkg.com/three@0.160.0/examples/jsm/loaders/GLTFLoader.js";
import { RGBELoader } from "https://unpkg.com/three@0.160.0/examples/jsm/loaders/RGBELoader.js";

const SCALE_FACTOR = 3.0;
let SMOOTHING_ALPHA = 0.22; // adjustable smoothing factor
const MIN_SCALE_PX = 18;      // clamp scale to reasonable pixel range
const MAX_SCALE_PX = 140;

let video;
let canvas;
let renderer;
let scene;
let camera;
let ring = null;
let hands = null;
let videoWidth = 0;
let videoHeight = 0;
let pmremGenerator = null;
let dirLight = null;
let occluder = null;

// Smoothed state
let sX = null;
let sY = null;
let sAngle = null;
let sScale = null;
let sending = false; // mediapipe frame gating
let calibrating = false;
let calibBuf = [];
const CALIB_SAMPLES = 20;
let lastBasisQuat = null;
let lastAcrossLen2D = null;

function initThree() {
    renderer = new THREE.WebGLRenderer({
        canvas: canvas,
        alpha: true,
        antialias: true
    });
    renderer.setSize(videoWidth, videoHeight);
    renderer.setClearColor(0x000000, 0);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.0;

    scene = new THREE.Scene();

    // Pixel-space orthographic camera (origin top-left, Y down)
    // World units map 1:1 to pixels.
    camera = new THREE.OrthographicCamera(0, videoWidth, 0, videoHeight, 0.1, 1000);
    camera.position.set(0, 0, 10);
    camera.lookAt(0, 0, 0);

    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    scene.add(ambientLight);

    dirLight = new THREE.DirectionalLight(0xffffff, params.lightIntensity);
    dirLight.position.set(-0.5, -0.5, 1);
    scene.add(dirLight);

    // Environment map for metallic materials (to avoid black look)
    pmremGenerator = new THREE.PMREMGenerator(renderer);
    pmremGenerator.compileEquirectangularShader();
    new RGBELoader()
        .setDataType(THREE.UnsignedByteType)
        .load(
            // Public HDRI from three.js examples (CORS-enabled)
            'https://threejs.org/examples/textures/equirectangular/royal_esplanade_1k.hdr',
            (texture) => {
                const envMap = pmremGenerator.fromEquirectangular(texture).texture;
                scene.environment = envMap;
                texture.dispose();
                pmremGenerator.dispose();
                console.log('Environment map set');
            },
            undefined,
            (err) => console.warn('Env map load failed', err)
        );

    console.log('Three.js initialized');
}

function loadRing() {
    const loader = new GLTFLoader();
    loader.load(
        'ring_test.glb',
        (gltf) => {
            ring = gltf.scene;
            
            const box = new THREE.Box3().setFromObject(ring);
            const size = box.getSize(new THREE.Vector3());
            const maxDim = Math.max(size.x, size.y, size.z);
            
            const targetSizePixels = 80;
            const baseScale = targetSizePixels / maxDim; // store base scale in pixels

            ring.userData.targetSizePixels = targetSizePixels;
            ring.userData.baseScale = baseScale;

            ring.scale.set(baseScale, baseScale, baseScale);
            ring.position.set(videoWidth / 2, videoHeight / 2, 0);
            ring.rotation.set(0, 0, 0);
            ring.visible = true;

            scene.add(ring);
            console.log('Ring loaded at center position');

            // Boost material reflectance with env map if present
            applyMaterialTuning();

            // Compute center offset based on ring band mesh to better align to finger axis
            let bandMesh = null;
            ring.traverse((o) => {
                if (o.isMesh) {
                    const name = (o.name || '').toLowerCase();
                    if (name.includes('ringband') || name.includes('band')) {
                        bandMesh = o;
                    }
                }
            });
            if (!bandMesh) {
                // fallback: pick the largest mesh by bounding box size
                let maxVol = -Infinity;
                ring.traverse((o) => {
                    if (o.isMesh) {
                        const bb = new THREE.Box3().setFromObject(o);
                        const sz = bb.getSize(new THREE.Vector3());
                        const vol = sz.x * sz.y * sz.z;
                        if (vol > maxVol) { maxVol = vol; bandMesh = o; }
                    }
                });
            }
            if (bandMesh) {
                const bb = new THREE.Box3().setFromObject(bandMesh);
                const centerWorld = bb.getCenter(new THREE.Vector3());
                const centerLocal = ring.worldToLocal(centerWorld.clone());
                ring.userData.centerOffsetBase = centerLocal; // in ring-local units after baseScale
                console.log('Center offset (base):', centerLocal.toArray());
            }
        },
        undefined,
        (error) => {
            console.error('Error loading ring:', error);
        }
    );
}

function initMediaPipe() {
    function tryInit(attempts = 0) {
        if (typeof Hands === 'undefined') {
            if (attempts < 50) {
                setTimeout(() => tryInit(attempts + 1), 100);
            } else {
                console.error('MediaPipe Hands failed to load');
            }
            return;
        }
        
        console.log('Initializing MediaPipe Hands...');
        hands = new Hands({
            locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`,
        });

        hands.setOptions({
            maxNumHands: 1,
            minDetectionConfidence: 0.6,
            minTrackingConfidence: 0.6,
            selfieMode: false,
            modelComplexity: 1,
        });

        hands.onResults(onResults);
        
        console.log('MediaPipe Hands initialized');
    }
    
    tryInit();
}

function onResults(results) {
    if (!ring || !results.multiHandLandmarks || results.multiHandLandmarks.length === 0) {
        return;
    }

    const landmarks = results.multiHandLandmarks[0];
    const world = results.multiHandWorldLandmarks ? results.multiHandWorldLandmarks[0] : null;

    if (landmarks.length < 17) return;

    // 2D pixel anchors
    const mcp2 = landmarks[13];
    const pip2 = landmarks[14];
    const midMcp2 = landmarks[9]; // middle finger MCP

    const x1 = mcp2.x * videoWidth;
    const y1 = mcp2.y * videoHeight;
    const x2 = pip2.x * videoWidth;
    const y2 = pip2.y * videoHeight;

    const dx2 = x2 - x1;
    const dy2 = y2 - y1;
    const angle2D = Math.atan2(dy2, dx2);

    const t = params.anchorT; // between MCP and PIP
    const centerX = x1 + dx2 * t;
    const centerY = y1 + dy2 * t;

    // Smoothing for 2D center and in-plane angle
    sX = sX === null ? centerX : sX + SMOOTHING_ALPHA * (centerX - sX);
    sY = sY === null ? centerY : sY + SMOOTHING_ALPHA * (centerY - sY);
    if (sAngle === null) {
        sAngle = angle2D;
    } else {
        let delta = angle2D - sAngle;
        delta = Math.atan2(Math.sin(delta), Math.cos(delta));
        sAngle = sAngle + SMOOTHING_ALPHA * delta;
    }

    // 3D orientation using normalized-z (or world if available)
    let tangent = new THREE.Vector3();
    let palmN = new THREE.Vector3();
    if (world && world.length >= 21) {
        const mcp = world[13];
        const pip = world[14];
        tangent.set(pip.x - mcp.x, pip.y - mcp.y, pip.z - mcp.z);
        const wrist = world[0];
        const indexMcp = world[5];
        const pinkyMcp = world[17];
        const v1 = new THREE.Vector3(indexMcp.x - wrist.x, indexMcp.y - wrist.y, indexMcp.z - wrist.z);
        const v2 = new THREE.Vector3(pinkyMcp.x - wrist.x, pinkyMcp.y - wrist.y, pinkyMcp.z - wrist.z);
        palmN.copy(v1.clone().cross(v2)).normalize();
    } else {
        const mcp = landmarks[13];
        const pip = landmarks[14];
        tangent.set(
            (pip.x - mcp.x) * videoWidth,
            (pip.y - mcp.y) * videoHeight,
            (pip.z - mcp.z) * videoWidth
        );
        const wrist = landmarks[0];
        const indexMcp = landmarks[5];
        const pinkyMcp = landmarks[17];
        const v1 = new THREE.Vector3(
            (indexMcp.x - wrist.x) * videoWidth,
            (indexMcp.y - wrist.y) * videoHeight,
            (indexMcp.z - wrist.z) * videoWidth
        );
        const v2 = new THREE.Vector3(
            (pinkyMcp.x - wrist.x) * videoWidth,
            (pinkyMcp.y - wrist.y) * videoHeight,
            (pinkyMcp.z - wrist.z) * videoWidth
        );
        palmN.copy(v1.clone().cross(v2)).normalize();
    }

    // Build orthonormal basis using palm normal for stability
    tangent.normalize();
    let across = palmN.clone().cross(tangent).normalize();
    if (across.lengthSq() < 1e-6) {
        // fallback: use middle MCP direction if palmN is unstable
        const midMcp2 = landmarks[9];
        across.set((midMcp2.x - mcp2.x) * videoWidth, (midMcp2.y - mcp2.y) * videoHeight, ((midMcp2.z ?? 0) - (mcp2.z ?? 0)) * videoWidth).normalize();
    }
    const normal = new THREE.Vector3().crossVectors(tangent, across).normalize();

    // Create rotation aligning ring's local axes: X=across, Y=tangent, Z=normal
    const basis = new THREE.Matrix4();
    basis.makeBasis(across, tangent, normal);
    const basisQuat = new THREE.Quaternion().setFromRotationMatrix(basis);
    lastBasisQuat = basisQuat.clone();

    // Scale from 3D segment length
    const dx3 = (pip2.x - mcp2.x) * videoWidth;
    const dy3 = (pip2.y - mcp2.y) * videoHeight;
    const dz3 = ((pip2.z ?? 0) - (mcp2.z ?? 0)) * videoWidth;
    const dist3D = Math.sqrt(dx3*dx3 + dy3*dy3 + dz3*dz3);

    const targetPx = Math.min(MAX_SCALE_PX, Math.max(MIN_SCALE_PX, (dist3D * SCALE_FACTOR) || 60));
    sScale = sScale === null ? targetPx : sScale + SMOOTHING_ALPHA * (targetPx - sScale);

    const baseScale = ring.userData?.baseScale || 1.0;
    const targetSizePixels = ring.userData?.targetSizePixels || 80;
    const scaleFactor = baseScale * (sScale / targetSizePixels) * params.scaleMult;

    // Apply fine orientation offsets from UI without accumulation
    const offQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(degToRad(params.pitch), degToRad(params.yaw), degToRad(params.roll), 'XYZ'));
    const finalQuat = basisQuat.clone().multiply(offQuat);

    // Adjust for model center offset so ring band is centered on the finger axis
    let posX = sX, posY = sY;
    const baseScale = ring.userData?.baseScale || 1.0;
    const targetSizePixels = ring.userData?.targetSizePixels || 80;
    const ratio = (sScale / targetSizePixels) * params.scaleMult;
    if (ring.userData && ring.userData.centerOffsetBase) {
        const scaledOffset = ring.userData.centerOffsetBase.clone().multiplyScalar(ratio);
        const rotated = scaledOffset.clone().applyQuaternion(finalQuat);
        posX -= rotated.x;
        posY -= rotated.y;
    }
    ring.position.set(posX, posY, 0);
    ring.scale.set(scaleFactor, scaleFactor, scaleFactor);
    ring.quaternion.copy(finalQuat);

    // Ensure occluder exists (created only when occlusion enabled)
    if (params.occEnable && !occluder) {
        const geo = new THREE.PlaneGeometry(1, 1);
        const mat = new THREE.MeshBasicMaterial({ color: 0x000000 });
        mat.colorWrite = false; // write depth only, no color
        mat.depthWrite = true;
        mat.depthTest = true;
        mat.transparent = true;
        occluder = new THREE.Mesh(geo, mat);
        occluder.renderOrder = 0; // draw early
        scene.add(occluder);
    }

    // Update occluder if present
    if (occluder) {
        occluder.visible = !!params.occEnable;
        if (params.occEnable) {
            // Size occluder using across distance (finger thickness proxy)
            const acrossLen2D = Math.hypot((landmarks[9].x - landmarks[13].x) * videoWidth, (landmarks[9].y - landmarks[13].y) * videoHeight);
            lastAcrossLen2D = acrossLen2D;
            const fingerWidthPx = THREE.MathUtils.clamp(acrossLen2D * 1.0 * (params.occWidth ?? 1.0), 6, 100);
            const fingerThickPx = THREE.MathUtils.clamp(acrossLen2D * 0.6 * (params.occHeight ?? 0.9), 4, 80);

            occluder.scale.set(fingerWidthPx, fingerThickPx, 1);
            occluder.position.set(sX, sY, (params.occDepth ?? 0.08));
            occluder.quaternion.copy(finalQuat);
        }
    }
    
    // Collect calibration samples when active
    if (calibrating) {
        const acrossLen2D = Math.hypot((landmarks[9].x - landmarks[13].x) * videoWidth, (landmarks[9].y - landmarks[13].y) * videoHeight);
        calibBuf.push({ across: acrossLen2D, target: targetPx });
        if (calibBuf.length >= CALIB_SAMPLES) {
            const btn = document.getElementById('autoCalib');
            finishCalibration(btn);
        }
    }
}

function processFrame() {
    if (video.readyState === video.HAVE_ENOUGH_DATA && hands && !sending && !video.paused) {
        sending = true;
        hands.send({ image: video }).catch((e) => {
            console.warn('Hands send error:', e);
        }).finally(() => {
            sending = false;
        });
    }
    requestAnimationFrame(processFrame);
}

function render() {
    if (renderer && scene && camera) {
        renderer.render(scene, camera);
    }
    requestAnimationFrame(render);
}

function init() {
    video = document.getElementById('video');
    canvas = document.getElementById('three-canvas');
    const container = document.getElementById('container');
    
    if (!video || !canvas) {
        console.error('Video or canvas not found');
        return;
    }
    
    video.addEventListener('loadedmetadata', () => {
        videoWidth = video.videoWidth;
        videoHeight = video.videoHeight;
        
        console.log(`Video dimensions: ${videoWidth} x ${videoHeight}`);
        
        // Size DOM elements to match video pixels
        if (container) {
            container.style.width = `${videoWidth}px`;
            container.style.height = `${videoHeight}px`;
        }

        video.width = videoWidth;
        video.height = videoHeight;
        canvas.width = videoWidth;
        canvas.height = videoHeight;
        
        initThree();
        loadRing();
        initMediaPipe();
        bindControls();
        
        processFrame();
        render();
    });

    video.addEventListener('error', (e) => {
        console.error('Video error:', e, video.error);
    });
    
    video.load();
}

init();
// UI-adjustable parameters
const params = {
    anchorT: 0.35,
    scaleMult: 1.0,
    smoothAlpha: 0.22,
    envIntensity: 1.2,
    lightIntensity: 1.2,
    yaw: 0,
    pitch: 0,
    roll: 0,
    forceGold: false,
    occDepth: 0.08,
    occWidth: 1.0,
    occHeight: 0.9,
    occEnable: true,
};

function degToRad(d) { return d * Math.PI / 180; }

function bindControls() {
    const byId = (id) => document.getElementById(id);
    const setText = (id, v) => { const el = byId(id); if (el) el.textContent = v; };

    const update = () => {
        SMOOTHING_ALPHA = params.smoothAlpha;
        if (dirLight) dirLight.intensity = params.lightIntensity;
        applyMaterialTuning();
        applyCurrentPoseFromCache();
    };

    const sliders = [
        ['scaleMult','scaleVal', (v)=>params.scaleMult=parseFloat(v), (v)=>Number(v).toFixed(2)],
        ['anchorT','anchorVal', (v)=>params.anchorT=parseFloat(v), (v)=>Number(v).toFixed(2)],
        ['smoothAlpha','smoothVal', (v)=>params.smoothAlpha=parseFloat(v), (v)=>Number(v).toFixed(2)],
        ['envIntensity','envVal', (v)=>{params.envIntensity=parseFloat(v);}, (v)=>Number(v).toFixed(1)],
        ['lightIntensity','lightVal', (v)=>params.lightIntensity=parseFloat(v), (v)=>Number(v).toFixed(1)],
        ['yaw','yawVal', (v)=>params.yaw=parseInt(v,10), (v)=>v],
        ['pitch','pitchVal', (v)=>params.pitch=parseInt(v,10), (v)=>v],
        ['roll','rollVal', (v)=>params.roll=parseInt(v,10), (v)=>v],
        ['occDepth','occDepthVal', (v)=>params.occDepth=parseFloat(v), (v)=>Number(v).toFixed(2)],
        ['occWidth','occWVal', (v)=>params.occWidth=parseFloat(v), (v)=>Number(v).toFixed(2)],
        ['occHeight','occHVal', (v)=>params.occHeight=parseFloat(v), (v)=>Number(v).toFixed(2)],
    ];
    sliders.forEach(([id,lbl,set,fmt])=>{
        const el = byId(id); if(!el) return;
        const lab = byId(lbl);
        const renderVal = ()=>{ if(lab) lab.textContent = fmt(el.value); };
        renderVal();
        el.addEventListener('input', ()=>{ set(el.value); renderVal(); update(); });
        el.addEventListener('change', ()=>{ set(el.value); renderVal(); update(); });
    });

    const occEnable = byId('occEnable');
    if (occEnable) {
        occEnable.addEventListener('change', ()=>{ params.occEnable = !!occEnable.checked; applyCurrentPoseFromCache(); });
    }

    const forceGold = byId('forceGold');
    if (forceGold) {
        forceGold.addEventListener('change', ()=>{ params.forceGold = forceGold.checked; applyMaterialTuning(); });
    }

    const pauseBtn = byId('pause');
    if (pauseBtn) {
        const setLabel = ()=>{ pauseBtn.textContent = video && !video.paused ? 'Pause' : 'Play'; };
        pauseBtn.addEventListener('click', ()=>{
            if (!video) return;
            if (video.paused) { video.play(); }
            else { video.pause(); }
            setLabel();
        });
        setLabel();
    }

    const autoBtn = byId('autoCalib');
    if (autoBtn) {
        autoBtn.addEventListener('click', ()=>{
            calibBuf = [];
            calibrating = true;
            autoBtn.disabled = true;
            autoBtn.textContent = 'Calibrating...';
            setTimeout(()=>{
                if (calibrating) finishCalibration(autoBtn);
            }, 4000);
        });
    }

    const reset = byId('reset');
    if (reset) {
        reset.addEventListener('click', ()=>{
            Object.assign(params, {anchorT:0.35, scaleMult:1.0, smoothAlpha:0.22, envIntensity:1.2, lightIntensity:1.2, yaw:0, pitch:0, roll:0, forceGold:false, occDepth:0.08, occWidth:1.0, occHeight:0.9, occEnable:true});
            sliders.forEach(([id,lbl])=>{ const el=byId(id); if(el){ el.value = String(params[id]); } });
            if (forceGold) forceGold.checked = false;
            sliders.forEach(([id,lbl,,fmt])=>{ const lab=byId(lbl); const el=byId(id); if(lab&&el){ lab.textContent = fmt(el.value); } });
            update();
        });
    }
}

function finishCalibration(btn){
    calibrating = false;
    if (btn) { btn.disabled = false; btn.textContent = 'Auto-Calibrate'; }
    if (calibBuf.length < 3) return;
    const mean = (arr)=> arr.reduce((a,b)=>a+b,0)/arr.length;
    const acrossMean = mean(calibBuf.map(s=>s.across));
    const targetMean = mean(calibBuf.map(s=>s.target));
    const desiredPx = acrossMean * 1.15;
    const newScaleMult = THREE.MathUtils.clamp(desiredPx / targetMean, 0.5, 2.0);
    params.scaleMult = newScaleMult;
    const scaleSlider = document.getElementById('scaleMult');
    const scaleVal = document.getElementById('scaleVal');
    if (scaleSlider) scaleSlider.value = String(newScaleMult);
    if (scaleVal) scaleVal.textContent = newScaleMult.toFixed(2);
}

function applyMaterialTuning() {
    if (!ring) return;
    ring.traverse((obj) => {
        if (obj.isMesh && obj.material) {
            const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
            mats.forEach((mat)=>{
                if ('envMapIntensity' in mat) mat.envMapIntensity = params.envIntensity;
                if (params.forceGold) {
                    if ('metalness' in mat) mat.metalness = 1.0;
                    if ('roughness' in mat) mat.roughness = 0.2;
                    if ('color' in mat && mat.color && mat.color.setRGB) mat.color.setRGB(0.95, 0.78, 0.25);
                }
                mat.needsUpdate = true;
            });
        }
    });
}

function applyCurrentPoseFromCache() {
    if (!ring || sX === null || sY === null || sScale === null) return;
    const baseScale = ring.userData?.baseScale || 1.0;
    const targetSizePixels = ring.userData?.targetSizePixels || 80;
    const scaleFactor = baseScale * (sScale / targetSizePixels) * params.scaleMult;
    ring.position.set(sX, sY, 0);
    ring.scale.set(scaleFactor, scaleFactor, scaleFactor);
    if (lastBasisQuat) {
        const offQuat = new THREE.Quaternion().setFromEuler(new THREE.Euler(degToRad(params.pitch), degToRad(params.yaw), degToRad(params.roll), 'XYZ'));
        const finalQuat = lastBasisQuat.clone().multiply(offQuat);
        ring.quaternion.copy(finalQuat);
        if (occluder) {
            const acrossLen2D = lastAcrossLen2D ?? 30;
            const fingerWidthPx = THREE.MathUtils.clamp(acrossLen2D * 0.9 * (params.occWidth ?? 1.0), 8, 80);
            const bandHeightPx = THREE.MathUtils.clamp((sScale || 60) * 0.9 * (params.occHeight ?? 0.9), 6, 140);
            occluder.scale.set(fingerWidthPx, bandHeightPx, 1);
            occluder.position.set(sX, sY, (params.occDepth ?? 0.08));
            occluder.quaternion.copy(finalQuat);
        }
    }
}

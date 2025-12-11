"""
Blender Ring Generator Script

Usage:
1. Open Blender
2. Go to Scripting workspace
3. Open this file in the Text Editor
4. Click "Run Script" or press Alt+P
5. Check the output directory for ring_test.glb

The script will generate a parametric ring and export it as GLB.
"""

import bpy
import bmesh
from dataclasses import dataclass
from mathutils import Vector

MM_TO_M = 0.001


@dataclass
class RingConfig:
    inner_diameter_mm: float = 18.0
    band_thickness_mm: float = 1.5
    band_width_mm: float = 3.0
    stone_radius_mm: float = 3.0
    stone_height_mm: float = 4.0
    add_stone: bool = True


def cleanup_scene():
    """Remove all objects and clean up unused data."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    for mesh in bpy.data.meshes:
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    
    for material in bpy.data.materials:
        if material.users == 0:
            bpy.data.materials.remove(material)
    
    for image in bpy.data.images:
        if image.users == 0:
            bpy.data.images.remove(image)


def create_gold_material():
    """Create or return existing gold material."""
    mat_name = "Gold"
    if mat_name in bpy.data.materials:
        return bpy.data.materials[mat_name]
    
    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.2
    bsdf.inputs["Base Color"].default_value = (0.831, 0.686, 0.216, 1.0)
    
    return mat


def create_stone_material():
    """Create or return existing stone material."""
    mat_name = "Stone"
    if mat_name in bpy.data.materials:
        return bpy.data.materials[mat_name]
    
    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.1
    bsdf.inputs["Base Color"].default_value = (0.8, 0.85, 0.9, 1.0)
    
    return mat


def create_ring_band(config: RingConfig):
    """Create the ring band using a torus."""
    inner_radius_m = (config.inner_diameter_mm / 2.0) * MM_TO_M
    major_radius = inner_radius_m + (config.band_thickness_mm * MM_TO_M)
    minor_radius = (config.band_width_mm / 2.0) * MM_TO_M
    
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=(0, 0, 0)
    )
    
    ring_obj = bpy.context.active_object
    ring_obj.name = "RingBand"
    
    ring_obj.location = (0, 0, 0)
    
    return ring_obj


def create_stone(config: RingConfig, ring_obj):
    """Create a simple stone object positioned on top of the ring."""
    stone_radius_m = config.stone_radius_mm * MM_TO_M
    stone_height_m = config.stone_height_mm * MM_TO_M
    
    inner_radius_m = (config.inner_diameter_mm / 2.0) * MM_TO_M
    band_width_m = config.band_width_mm * MM_TO_M
    
    bpy.ops.mesh.primitive_cylinder_add(
        radius=stone_radius_m,
        depth=stone_height_m,
        location=(0, inner_radius_m + band_width_m / 2, stone_height_m / 2)
    )
    
    stone_obj = bpy.context.active_object
    stone_obj.name = "Stone"
    
    return stone_obj


def build_ring_scene(config: RingConfig):
    """Build the complete ring scene with band and optional stone."""
    cleanup_scene()
    
    ring_obj = create_ring_band(config)
    gold_mat = create_gold_material()
    ring_obj.data.materials.append(gold_mat)
    
    stone_obj = None
    if config.add_stone:
        stone_obj = create_stone(config, ring_obj)
        stone_mat = create_stone_material()
        stone_obj.data.materials.append(stone_mat)
    
    return ring_obj, stone_obj


def export_glb(config: RingConfig, output_path: str):
    """Build the ring scene and export as GLB."""
    ring_obj, stone_obj = build_ring_scene(config)
    
    bpy.ops.object.select_all(action='DESELECT')
    ring_obj.select_set(True)
    if stone_obj:
        stone_obj.select_set(True)
    
    bpy.context.view_layer.objects.active = ring_obj
    
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if stone_obj:
        stone_obj.select_set(True)
        bpy.context.view_layer.objects.active = stone_obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    bpy.ops.object.select_all(action='DESELECT')
    ring_obj.select_set(True)
    if stone_obj:
        stone_obj.select_set(True)
    
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        use_selection=True,
        export_format='GLB',
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False
    )


if __name__ == "__main__":
    config = RingConfig(
        inner_diameter_mm=18.0,
        band_thickness_mm=1.5,
        band_width_mm=3.0,
        stone_radius_mm=3.0,
        stone_height_mm=4.0,
        add_stone=True
    )
    
    import os
    output_path = os.path.join(os.path.dirname(__file__), "ring_test.glb")
    export_glb(config, output_path)
    print(f"Ring exported to {output_path}")


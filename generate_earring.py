"""
Blender Earring Generator Script

Usage:
1. Open Blender
2. Go to Scripting workspace
3. Open this file in the Text Editor
4. Click "Run Script" or press Alt+P
5. Check the output directory for earring_test.glb

The script will generate a parametric earring with:
- One large rectangular blue stone at the top
- Three smaller blue teardrop stones below it
- A semicircle halo of round white stones around the bottom
- A metal backing plate and optional post

The earring is oriented with the front facing +Y direction.
The origin is at the top-center of the main stone (attachment point).
"""

import bpy
import bmesh
from dataclasses import dataclass
from mathutils import Vector
import math
import random

MM_TO_M = 0.001


@dataclass
class EarringConfig:
    main_stone_width_mm: float = 8.0
    main_stone_height_mm: float = 12.0
    main_stone_thickness_mm: float = 3.0
    cluster_width_mm: float = 14.0
    cluster_height_mm: float = 12.0
    cluster_stone_count: int = 20
    cluster_blue_stone_count: int = 4
    cluster_stone_radius_mm: float = 1.2
    metal_thickness_mm: float = 0.5
    add_post: bool = True


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


def create_blue_gem_material():
    """Create or return existing blue gem material (sapphire-like)."""
    mat_name = "BlueGem"
    if mat_name in bpy.data.materials:
        return bpy.data.materials[mat_name]
    
    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    
    # Vibrant sapphire-like blue color
    bsdf.inputs["Base Color"].default_value = (0.05, 0.2, 0.7, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["IOR"].default_value = 1.77  # Sapphire IOR
    # Use alpha for transparency if needed
    mat.blend_method = 'BLEND'
    mat.show_transparent_back = False
    
    return mat


def create_white_gem_material():
    """Create or return existing white gem material (diamond-like)."""
    mat_name = "WhiteGem"
    if mat_name in bpy.data.materials:
        return bpy.data.materials[mat_name]
    
    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    
    # Brilliant diamond-like color
    bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.0
    bsdf.inputs["IOR"].default_value = 2.42  # Diamond IOR
    # Use alpha for transparency if needed
    mat.blend_method = 'BLEND'
    mat.show_transparent_back = False
    
    return mat


def create_metal_material():
    """Create or return existing metal material (silver/white gold)."""
    mat_name = "Metal"
    if mat_name in bpy.data.materials:
        return bpy.data.materials[mat_name]
    
    mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    
    # Silver/white gold color
    bsdf.inputs["Base Color"].default_value = (0.9, 0.9, 0.95, 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.15
    
    return mat


def create_main_stone(config: EarringConfig):
    """Create the main rectangular blue stone with emerald-cut facets."""
    width = config.main_stone_width_mm * MM_TO_M
    height = config.main_stone_height_mm * MM_TO_M
    thickness = config.main_stone_thickness_mm * MM_TO_M
    
    # Create a cube and scale it
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    main_stone = bpy.context.active_object
    main_stone.name = "MainStone"
    
    # Scale to desired dimensions
    main_stone.scale = (width, thickness, height)
    
    # Position so origin is at top-center (attachment point)
    main_stone.location = (0, 0, -height / 2)
    
    # Add bevel for emerald-cut facets on edges - more pronounced
    bpy.ops.object.modifier_add(type='BEVEL')
    main_stone.modifiers["Bevel"].width = thickness * 0.35
    main_stone.modifiers["Bevel"].segments = 5
    main_stone.modifiers["Bevel"].limit_method = 'ANGLE'
    main_stone.modifiers["Bevel"].angle_limit = math.radians(60)
    
    # Add subdivision for smoother appearance but keep some faceting
    bpy.ops.object.modifier_add(type='SUBSURF')
    main_stone.modifiers["Subdivision"].levels = 1
    main_stone.modifiers["Subdivision"].render_levels = 1
    
    return main_stone


def create_cluster_stones(config: EarringConfig):
    """Create a heart-like cluster of mixed white and blue stones."""
    cluster_width = config.cluster_width_mm * MM_TO_M
    cluster_height = config.cluster_height_mm * MM_TO_M
    stone_radius = config.cluster_stone_radius_mm * MM_TO_M
    
    # Position below main stone with small gap - ensure stones are in front (positive Y)
    main_stone_bottom = -(config.main_stone_height_mm * MM_TO_M) / 2
    gap = 1.0 * MM_TO_M
    cluster_top_z = main_stone_bottom - gap
    cluster_center_z = cluster_top_z - cluster_height / 2
    
    # Position stones in front of backing plate (positive Y) - make them clearly visible
    stone_y_position = config.main_stone_thickness_mm * MM_TO_M * 0.5
    
    cluster_stones = []
    
    total_stones = config.cluster_stone_count
    blue_stone_indices = set()
    
    # Select which stones will be blue (in the center area)
    random.seed(42)  # For reproducibility
    center_start = total_stones // 4
    center_end = 3 * total_stones // 4
    center_stone_indices = list(range(center_start, center_end))
    blue_indices = random.sample(center_stone_indices, min(config.cluster_blue_stone_count, len(center_stone_indices)))
    blue_stone_indices = set(blue_indices)
    
    # Create heart-like pattern: wider semicircle on top, narrowing V on bottom
    for i in range(total_stones):
        t = i / (total_stones - 1) if total_stones > 1 else 0.5
        
        if t < 0.48:
            # Top semicircle part (wider) - more pronounced curve
            angle = math.radians(180 * (1 - 2 * t / 0.48))
            x = (cluster_width / 2) * math.cos(angle)
            z_offset = cluster_height * 0.38 * math.sin(angle)
        else:
            # Bottom V-shape (heart point) - more symmetric and pronounced
            t_bottom = (t - 0.48) / 0.52
            # Create symmetric V that narrows to a point
            # Alternate between left and right for V shape
            bottom_index = i - int(total_stones * 0.48)
            side = 1 if (bottom_index % 2 == 0) else -1
            width_factor = 1.0 - t_bottom * 0.8  # Narrow from full width to 20%
            x = side * (cluster_width / 2) * width_factor
            z_offset = -cluster_height * (0.38 + 0.62 * t_bottom)
        
        z = cluster_center_z + z_offset
        
        # Add slight randomness for natural cluster look
        x += (random.random() - 0.5) * stone_radius * 0.15
        z += (random.random() - 0.5) * stone_radius * 0.15
        
        # Create sphere for each stone with more subdivisions for better appearance
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=3,
            radius=stone_radius,
            location=(x, stone_y_position, z)
        )
        stone = bpy.context.active_object
        stone.name = f"ClusterStone_{i}"
        cluster_stones.append((stone, i in blue_stone_indices))
    
    return cluster_stones


def create_backing_plate(config: EarringConfig):
    """Create a thin metal backing plate behind all stones."""
    # Calculate overall dimensions
    width = max(config.main_stone_width_mm, config.cluster_width_mm) * MM_TO_M
    height = (config.main_stone_height_mm + config.cluster_height_mm + 1.0) * MM_TO_M
    
    # Backing plate dimensions (slightly larger than stones)
    plate_width = width * 1.1
    plate_height = height * 0.95
    plate_thickness = config.metal_thickness_mm * MM_TO_M
    
    # Create a rounded rectangle using a cube
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    plate = bpy.context.active_object
    plate.name = "BackingPlate"
    
    # Scale to dimensions
    plate.scale = (plate_width, plate_thickness, plate_height)
    
    # Position behind stones (negative Y) and centered vertically
    main_stone_bottom = -(config.main_stone_height_mm * MM_TO_M) / 2
    cluster_top_z = main_stone_bottom - 1.0 * MM_TO_M
    cluster_center_z = cluster_top_z - (config.cluster_height_mm * MM_TO_M) / 2
    plate_center_z = (0 + cluster_center_z) / 2
    
    plate.location = (0, -plate_thickness / 2 - config.main_stone_thickness_mm * MM_TO_M / 2, plate_center_z)
    
    # Add slight bevel for rounded edges
    bpy.ops.object.modifier_add(type='BEVEL')
    plate.modifiers["Bevel"].width = plate_thickness * 0.3
    plate.modifiers["Bevel"].segments = 3
    
    return plate


def create_post(config: EarringConfig):
    """Create a small post at the back for ear attachment."""
    post_radius = 0.5 * MM_TO_M
    post_length = 3.0 * MM_TO_M
    
    # Create cylinder for post
    bpy.ops.mesh.primitive_cylinder_add(
        radius=post_radius,
        depth=post_length,
        location=(0, 0, 0)
    )
    post = bpy.context.active_object
    post.name = "Post"
    
    # Position at the back, extending from the top of the main stone
    post.location = (0, -config.main_stone_thickness_mm * MM_TO_M / 2 - post_length / 2, 0)
    
    return post


def build_earring_scene(config: EarringConfig):
    """Build the complete earring scene with all components."""
    cleanup_scene()
    
    # Create materials
    blue_gem_mat = create_blue_gem_material()
    white_gem_mat = create_white_gem_material()
    metal_mat = create_metal_material()
    
    # Create main stone
    main_stone = create_main_stone(config)
    main_stone.data.materials.append(blue_gem_mat)
    
    # Create cluster stones (heart-like pattern with mixed white and blue)
    cluster_stones = create_cluster_stones(config)
    cluster_objects = []
    for stone, is_blue in cluster_stones:
        if is_blue:
            stone.data.materials.append(blue_gem_mat)
        else:
            stone.data.materials.append(white_gem_mat)
        cluster_objects.append(stone)
    
    # Create backing plate
    backing_plate = create_backing_plate(config)
    backing_plate.data.materials.append(metal_mat)
    
    # Create post if requested
    post = None
    if config.add_post:
        post = create_post(config)
        post.data.materials.append(metal_mat)
    
    # Don't parent cluster objects - keep them separate for better visibility
    # Only parent backing plate and post
    backing_plate.parent = main_stone
    if post:
        post.parent = main_stone
    
    return main_stone


def export_glb(config: EarringConfig, output_path: str):
    """Build the earring scene and export as GLB."""
    earring_root = build_earring_scene(config)
    
    # Select all earring objects
    bpy.ops.object.select_all(action='DESELECT')
    
    # Select all earring objects (root, children, and cluster stones)
    earring_root.select_set(True)
    for child in earring_root.children:
        child.select_set(True)
    
    # Also select all cluster stones (they're not parented)
    for obj in bpy.context.scene.objects:
        if obj.name.startswith("ClusterStone_"):
            obj.select_set(True)
    
    bpy.context.view_layer.objects.active = earring_root
    
    # Apply transforms and modifiers to all selected objects
    selected_objects = [obj for obj in bpy.context.selected_objects]
    for obj in selected_objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        # Apply modifiers
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    
    # Select all again after applying transforms
    bpy.ops.object.select_all(action='DESELECT')
    earring_root.select_set(True)
    for child in earring_root.children:
        child.select_set(True)
    for obj in bpy.context.scene.objects:
        if obj.name.startswith("ClusterStone_"):
            obj.select_set(True)
    
    # Export as GLB
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        use_selection=True,
        export_format='GLB',
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False
    )


if __name__ == "__main__":
    # Sample configuration that matches the reference design
    config = EarringConfig(
        main_stone_width_mm=6.5,
        main_stone_height_mm=9.5,
        main_stone_thickness_mm=2.8,
        cluster_width_mm=11.5,
        cluster_height_mm=9.5,
        cluster_stone_count=28,
        cluster_blue_stone_count=6,
        cluster_stone_radius_mm=1.4,
        metal_thickness_mm=0.4,
        add_post=True
    )
    
    import os
    output_path = os.path.join(os.path.dirname(__file__), "earring_test.glb")
    export_glb(config, output_path)
    print(f"Earring exported to {output_path}")


"""
Blender Utility Functions for Reliable 3D Modeling

This module contains helper functions learned from creating an abstract blocky tree.
These functions address common challenges in programmatic Blender modeling:
- Position management and object relationships
- Safe scaling without position drift
- Material creation and assignment
- Object grouping and naming
- Transform safety and error recovery

Key Insights from the Project:
- Basic primitive creation and materials: EASY
- Absolute positioning and composition: HARD
- Scale operations affect both size and position: CHALLENGING
- Visual verification essential for complex operations
- Iterative refinement with feedback crucial for success
"""

import math
import random
from typing import Any, List, Tuple

import bpy
from mathutils import Euler, Vector


def clear_scene():
    """Safely clear all objects from the scene."""
    try:
        bpy.ops.object.select_all(action="SELECT")
        if bpy.context.selected_objects:
            bpy.ops.object.delete(use_global=False)
        print("Scene cleared successfully")
    except Exception as e:
        print(f"Warning: Scene clear had issues: {e}")


def create_material(
    name: str,
    color: Tuple[float, float, float, float],
    roughness: float = 0.8,
    metallic: float = 0.0,
) -> Any:
    """Create a basic material with specified properties.

    Args:
        name: Material name
        color: RGBA color tuple (0-1 range)
        roughness: Surface roughness (0-1)
        metallic: Metallic property (0-1)

    Returns:
        Created material object
    """
    material = bpy.data.materials.new(name=name)
    material.use_nodes = True

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    # Add Principled BSDF and Material Output
    bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    output = nodes.new(type="ShaderNodeOutputMaterial")
    output.location = (200, 0)

    # Link and set properties
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic

    return material


def create_primitive(
    primitive_type: str,
    name: str,
    location: Tuple[float, float, float],
    scale: Tuple[float, float, float] = (1, 1, 1),
    rotation: Tuple[float, float, float] = (0, 0, 0),
) -> Any:
    """Create a primitive with specified properties.

    Args:
        primitive_type: 'cube', 'cylinder', 'sphere', etc.
        name: Object name
        location: XYZ position
        scale: XYZ scale factors
        rotation: XYZ rotation in radians

    Returns:
        Created object
    """
    # Create primitive based on type
    if primitive_type == "cube":
        bpy.ops.mesh.primitive_cube_add(location=location)
    elif primitive_type == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(location=location)
    elif primitive_type == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(location=location)
    else:
        raise ValueError(f"Unsupported primitive type: {primitive_type}")

    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = Euler(rotation, "XYZ")

    # Apply transforms for stability
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    return obj


def scale_in_place(obj: Any, scale_factor: float):
    """Scale an object without moving it away from its current position.

    This was a major issue in the tree project - scaling also moved objects
    away from their intended positions.
    """
    original_location = obj.location.copy()
    obj.scale = (
        obj.scale.x * scale_factor,
        obj.scale.y * scale_factor,
        obj.scale.z * scale_factor,
    )
    obj.location = original_location

    # Apply transform to make permanent
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def position_relative_to(
    child_obj: Any, parent_obj: Any, offset: Tuple[float, float, float]
):
    """Position an object relative to another object.

    This would have been much better than absolute positioning in the tree project.
    """
    parent_location = parent_obj.location
    child_obj.location = Vector(
        (
            parent_location.x + offset[0],
            parent_location.y + offset[1],
            parent_location.z + offset[2],
        )
    )


def create_cluster(
    base_location: Tuple[float, float, float],
    primitive_type: str,
    cluster_name: str,
    count: int,
    spread_radius: float,
    scale_range: Tuple[float, float],
    material: Any = None,
) -> List[Any]:
    """Create a cluster of objects with random variations.

    This would have simplified the leaf cluster creation significantly.

    Args:
        base_location: Center point of cluster
        primitive_type: Type of primitive to create
        cluster_name: Base name for objects
        count: Number of objects in cluster
        spread_radius: Maximum distance from center
        scale_range: Min and max scale factors
        material: Material to apply to all objects

    Returns:
        List of created objects
    """
    objects = []

    for i in range(count):
        # Random position within spread radius
        angle = random.uniform(0, 2 * math.pi)
        distance = random.uniform(0, spread_radius)

        x = base_location[0] + distance * math.cos(angle)
        y = base_location[1] + distance * math.sin(angle)
        z = base_location[2] + random.uniform(-spread_radius * 0.3, spread_radius * 0.3)

        # Random scale and rotation
        scale = random.uniform(scale_range[0], scale_range[1])
        rotation = (
            random.uniform(0, math.pi / 3),
            random.uniform(0, math.pi / 3),
            random.uniform(0, math.pi),
        )

        obj = create_primitive(
            primitive_type,
            f"{cluster_name}_{i + 1}",
            (x, y, z),
            (scale, scale, scale),
            rotation,
        )

        # Apply material if provided
        if material:
            obj.data.materials.clear()
            obj.data.materials.append(material)

        objects.append(obj)

    return objects


def apply_material_to_objects(objects: List[Any], material: Any):
    """Apply a material to multiple objects safely."""
    for obj in objects:
        if obj and obj.data:
            obj.data.materials.clear()
            obj.data.materials.append(material)


def get_objects_by_pattern(pattern: str) -> List[Any]:
    """Get all objects whose names start with a pattern."""
    return [obj for obj in bpy.data.objects if obj.name.startswith(pattern)]


def create_tree_trunk(
    segments: int,
    base_location: Tuple[float, float, float],
    height_per_segment: float,
    taper_factor: float = 0.9,
    offset_range: float = 0.2,
    rotation_range: float = 15,
) -> List[Any]:
    """Create a segmented tree trunk with natural variations.

    This captures the trunk creation pattern from the tree project.
    """
    trunk_segments = []
    current_z = base_location[2]
    current_scale = 1.0

    for i in range(segments):
        # Calculate position with offset
        offset_x = random.uniform(-offset_range, offset_range)
        offset_y = random.uniform(-offset_range, offset_range)

        location = (
            base_location[0] + offset_x,
            base_location[1] + offset_y,
            current_z + height_per_segment / 2,
        )

        # Calculate scale (tapering)
        scale = (current_scale, current_scale * 0.9, height_per_segment)

        # Random rotation
        rotation = (0, 0, math.radians(random.uniform(-rotation_range, rotation_range)))

        # Create segment
        name = f"Trunk_Seg_{i + 1}" if i > 0 else "Trunk_Base"
        segment = create_primitive("cube", name, location, scale, rotation)
        trunk_segments.append(segment)

        # Update for next segment
        current_z += height_per_segment
        current_scale *= taper_factor

    return trunk_segments


def create_branches_from_trunk(
    trunk_segments: List[Any], branches_per_segment: int = 1
) -> List[Any]:
    """Create branches extending from trunk segments.

    This automates the branch creation process.
    """
    branches = []

    for i, trunk_seg in enumerate(trunk_segments[1:], 1):  # Skip base segment
        trunk_location = trunk_seg.location

        for j in range(branches_per_segment):
            # Random direction and angle
            angle = random.uniform(0, 2 * math.pi)
            elevation = random.uniform(math.radians(20), math.radians(60))

            length = random.uniform(1.0, 1.8)
            direction = Vector(
                (
                    math.cos(angle) * math.cos(elevation),
                    math.sin(angle) * math.cos(elevation),
                    math.sin(elevation),
                )
            )

            branch_end = trunk_location + direction * length

            # Create branch
            branch = create_primitive(
                "cube",
                f"Branch_{i}_{j + 1}",
                (
                    (trunk_location.x + branch_end.x) / 2,
                    (trunk_location.y + branch_end.y) / 2,
                    (trunk_location.z + branch_end.z) / 2,
                ),
                (length, 0.3, 0.3),
                (0, elevation, angle),
            )

            branches.append(branch)

    return branches


# Convenience functions for common material presets
def create_bark_material(name: str = "Bark") -> Any:
    """Create a brown bark material."""
    return create_material(name, (0.3, 0.15, 0.08, 1.0), roughness=0.8)


def create_leaf_material(name: str = "Leaves") -> Any:
    """Create a bright green leaf material."""
    return create_material(name, (0.15, 0.6, 0.2, 1.0), roughness=0.6)


def create_stone_material(name: str = "Stone") -> Any:
    """Create a gray stone material."""
    return create_material(name, (0.5, 0.5, 0.5, 1.0), roughness=0.9)


# Project Reflection and Learnings
"""
REFLECTION ON THE ABSTRACT BLOCKY TREE PROJECT:

What Was Easy:
- Basic primitive creation (cubes, cylinders)
- Material creation and color assignment
- Simple transform operations (location, rotation, scale)
- Screenshot verification process
- Iterative development with user feedback

What Was Hard:
- Spatial positioning and composition without real-time visual feedback
- Understanding how scale affects both size AND position
- Managing object relationships (keeping leaves near branches)
- Complex mesh operations (the failed curved trunk attempt)
- Debugging visual misunderstandings from screenshot descriptions

What Would Have Been Better:
- Helper functions for relative positioning instead of absolute coordinates
- Cluster management for grouped objects like leaves
- Scale-in-place functionality to avoid position drift
- Automated branch-to-leaf positioning
- Better error recovery and validation

Key Technical Issues Solved:
1. Scaling objects moved them away from intended positions
   - Solution: Store original location, scale, then restore location
   
2. Manual positioning was error-prone and hard to visualize
   - Solution: Relative positioning based on parent objects
   
3. Creating clusters of similar objects was repetitive
   - Solution: Parameterized cluster creation functions
   
4. Material application to multiple objects was verbose
   - Solution: Batch material application helpers

The verification-driven approach with screenshots was excellent and should
be standard practice for any complex Blender scripting project.

The most valuable insight: When doing programmatic 3D modeling, invest heavily
in helper functions that manage spatial relationships rather than trying to
calculate absolute positions manually.

Why functions over a stateless class?
- Simpler imports: `from blender_util import create_primitive`
- No unnecessary BlenderHelper.method() syntax
- More Pythonic for utility functions
- Easier to compose and test individual functions
- Clearer intent - these are tools, not objects with state
"""


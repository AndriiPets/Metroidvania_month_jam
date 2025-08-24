extends Node

# Define the base folder where all VFX scenes are stored.
const VFX_BASE_PATH = "res://Gameplay/Components/Particles/"

## The runtime library, built dynamically upon startup.
var vfx_library: Dictionary = {}

func _ready():
    build_vfx_library(VFX_BASE_PATH)
    print("VFXManager initialized. Loaded ", vfx_library.size(), " effects.")

func build_vfx_library(path: String) -> void:
    var dir = DirAccess.open(path)
    if not dir:
        push_error("VFXManager: Cannot open VFX directory at: %s" % path)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        var full_path = path.path_join(file_name)
        if dir.current_is_dir():
            if file_name != "." and file_name != "..":
                build_vfx_library(full_path) # Recursive call
        
        elif file_name.ends_with(".tscn"):
            # 1. Load the PackedScene resource.
            var scene_resource = ResourceLoader.load(full_path, "PackedScene")
            if not scene_resource:
                push_warning("VFXManager: Failed to load scene at %s" % full_path)
                continue # Skip to the next file

            # 2. Briefly instantiate the scene to read its properties.
            var temp_instance = scene_resource.instantiate()
            if not is_instance_valid(temp_instance):
                push_warning("VFXManager: Failed to instance scene from %s" % full_path)
                continue

            # 3. Find the VFXInstance child node.
            var vfx_instance_node := _find_vfx_script_in_children(temp_instance)
            if vfx_instance_node and vfx_instance_node is VFXInstance:
                var vfx_id = vfx_instance_node.vfx_id
                
                # 4. If the ID is valid, add it to our library.
                if not vfx_id.is_empty():
                    if vfx_library.has(vfx_id):
                        push_warning("VFXManager: Duplicate vfx_id '%s' found. Overwriting." % vfx_id)
                    vfx_library[vfx_id] = scene_resource
                else:
                    push_warning("VFX scene '%s' found but its VFXInstance has a blank vfx_id." % full_path)
            else:
                push_warning("VFX scene '%s' does not contain a child with the VFXInstance script." % full_path)
                
            # 5. IMPORTANT: Free the temporary instance immediately.
            temp_instance.queue_free()
            
        file_name = dir.get_next()

func spawn_vfx(effect_id: StringName, global_position: Vector2, optional_params: Dictionary = {}) -> void:
    if not vfx_library.has(effect_id):
        push_warning("VFXManager: Tried to spawn non-existent effect with ID: '%s'" % effect_id)
        return
        
    var vfx_scene: PackedScene = vfx_library[effect_id]
    if not vfx_scene:
        push_error("VFXManager: Scene for effect ID '%s' is null." % effect_id)
        return
        
    var vfx_instance := vfx_scene.instantiate() as GPUParticles2D
    
    # Add the instance to the current scene tree.
    get_tree().current_scene.add_child(vfx_instance)
    
    vfx_instance.global_position = global_position
    
    if optional_params.has("rotation_degrees"):
        vfx_instance.rotation_degrees = optional_params["rotation_degrees"]
    if optional_params.has("scale"):
        vfx_instance.scale = optional_params["scale"]
    if optional_params.has("modulate"):
        vfx_instance.modulate = optional_params["modulate"]
    
    vfx_instance.emitting = true

func _find_vfx_script_in_children(node: Node) -> VFXInstance:
    for child in node.get_children():
        if child is VFXInstance:
            return child
    return null # Return null if no matching child is found
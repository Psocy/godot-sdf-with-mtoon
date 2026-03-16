@tool
extends Node3D

@export var shadow_material: Material
@export var use_defaults_if_unset: bool = true

var _sdf_enabled: bool = true
var _face_mi: MeshInstance3D = null
var _face_surface_idx: int = -1
var _mat_normal: ShaderMaterial = null
var _mat_sdf: ShaderMaterial = null
var _dir_light: DirectionalLight3D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_materials()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_materials()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_sdf_enabled = !_sdf_enabled
			if _face_mi != null and _face_surface_idx >= 0:
				var mat := _mat_sdf if _sdf_enabled else _mat_normal
				_face_mi.set_surface_override_material(_face_surface_idx, mat)
				print("[SDF] 토글: ", "SDF" if _sdf_enabled else "노말")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or shadow_material == null:
		return

	# 빛 방향 계산 (DirectionalLight3D 또는 OmniLight3D)
	var light_world_dir: Vector3
	var key_light := _find_light(get_tree().root)
	if key_light == null:
		return

	if key_light is DirectionalLight3D:
		light_world_dir = key_light.global_transform.basis.z
	else:
		# OmniLight3D: 빛 위치 → 캐릭터 얼굴 방향
		var face_pos: Vector3 = _face_mi.global_position if _face_mi != null else global_position
		light_world_dir = (face_pos - key_light.global_position).normalized()

	var light_xz := Vector2(light_world_dir.x, light_world_dir.z)
	if light_xz.length() < 0.001:
		return
	light_xz = light_xz.normalized()

	var char_fwd := Vector2(-global_transform.basis.z.x, -global_transform.basis.z.z).normalized()
	var char_right := Vector2(global_transform.basis.x.x, global_transform.basis.x.z).normalized()

	var fwd_dot: float = light_xz.dot(char_fwd)
	var right_dot: float = light_xz.dot(char_right)
	# theta: 0=빛이 정면(그림자 없음), 1=빛이 뒤(완전 그림자)
	var theta: float = 1.0 - (fwd_dot * 0.5 + 0.5)

	(shadow_material as ShaderMaterial).set_shader_parameter("light_dir_xz", Vector2(right_dot, theta))

func _find_light(node: Node) -> Light3D:
	if node is DirectionalLight3D:
		return node as Light3D
	if node is OmniLight3D:
		return node as Light3D
	for child in node.get_children():
		var result := _find_light(child)
		if result != null:
			return result
	return null

func _apply_materials() -> void:
	if use_defaults_if_unset and shadow_material == null:
		shadow_material = load("res://materials/face_sdf_shadow.tres")
	print("[SDF] _apply_materials 시작, shadow_material: ", shadow_material)
	_apply_to_meshes(self)

func _apply_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				var surface_name: String = mesh.surface_get_name(s)
				if surface_name == "N00_000_00_Face_00_SKIN":
					var orig_mat: Material = mesh.surface_get_material(s)
					print("[SDF] SKIN 서피스 발견: ", surface_name, " | orig_mat: ", orig_mat)
					if orig_mat != null and shadow_material != null:
						_face_mi = mi
						_face_surface_idx = s
						_mat_normal = orig_mat.duplicate() as ShaderMaterial
						_mat_sdf = orig_mat.duplicate() as ShaderMaterial
						var base_color: Color = _mat_sdf.get_shader_parameter("_Color")
						var shade_color: Color = _mat_sdf.get_shader_parameter("_ShadeColor")
						_mat_sdf.set_shader_parameter("_ShadeColor", base_color)
						_mat_sdf.set_shader_parameter("_ShadeShift", 1.0)
						_mat_sdf.next_pass = shadow_material
						(shadow_material as ShaderMaterial).set_shader_parameter("shadow_tint", shade_color)
						mi.set_surface_override_material(s, _mat_sdf)
						print("[SDF] next_pass 적용 완료: ", surface_name, " | base_color: ", base_color)
	for child in node.get_children():
		_apply_to_meshes(child)

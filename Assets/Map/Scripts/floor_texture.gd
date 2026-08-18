extends RefCounted

const TEXTURE_DIR := "res://Assets/Map/Textures"
const TEXTURE_PREFIX := "station_floor"
const MATERIAL_PATH := "res://Assets/Map/station_floor.tres"

var plane_size := Vector2(1.0, 1.0)
var panel_size := 0.2
var panels_per_tile := 4
var stagger_rows := false

var texture_resolution := 512
var noise_seed := 0

var base_color := Color("6a7183")
var groove_color := Color("262b39")
var bolt_color := Color("929aab")
var scratch_color := Color("bcc3d2")
var grime_color := Color("343a4a")

var grime_amount := 0.643
var scratch_amount := 0.778
var base_roughness := 0.45
var base_metallic := 0.6
var normal_strength := 1.0

var groove_width := 0.055
var bolt_inset := 0.145
var bolt_radius := 0.05

const _H_GROOVE := 0.55
const _H_BOLT := 0.35
const _H_SLOT := 0.20
const _H_SCRATCH := 0.10
const _H_GRAIN := 0.06
const _HEIGHT_WORLD := 0.05
const _SCRATCH_SHARPNESS := 14.0
const _STREAK_RATIO := 12


func save_images() -> PackedStringArray:
	DirAccess.make_dir_recursive_absolute(TEXTURE_DIR)
	var maps := bake_maps(clampi(texture_resolution, 16, 2048))
	var names := ["albedo", "orm", "normal"]
	var paths := PackedStringArray()
	for i in 3:
		var path := "%s/%s_%s.png" % [TEXTURE_DIR, TEXTURE_PREFIX, names[i]]
		maps[i].save_png(path)
		paths.append(path)
	return paths


func save_material(paths: PackedStringArray) -> void:
	var tile_world := maxf(panel_size * panels_per_tile, 0.001)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(paths[0])
	mat.roughness = 1.0
	mat.roughness_texture = load(paths[1])
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic = 1.0
	mat.metallic_texture = load(paths[1])
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.ao_enabled = true
	mat.ao_texture = load(paths[1])
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = true
	mat.normal_texture = load(paths[2])
	mat.normal_scale = normal_strength
	mat.uv1_scale = Vector3(plane_size.x / tile_world, plane_size.y / tile_world, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(mat, MATERIAL_PATH)


func bake_maps(n: int) -> Array[Image]:
	@warning_ignore("integer_division")
	var streak := maxi(n / _STREAK_RATIO, 4)
	var grime := _noise_bytes(_make_noise(noise_seed + 1, 0.012, 4), n, n)
	var grain := _noise_bytes(_make_noise(noise_seed + 2, 0.35, 2), n, n)
	var scratch_v := _noise_bytes(_make_noise(noise_seed + 3, 0.08, 3), n, streak)
	var scratch_h := _noise_bytes(_make_noise(noise_seed + 4, 0.08, 3), streak, n)
	var wear_v := _noise_bytes(_make_noise(noise_seed + 5, 0.02, 2), n, n)
	var wear_h := _noise_bytes(_make_noise(noise_seed + 6, 0.023, 2), n, n)

	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var albedo_data := PackedByteArray()
	albedo_data.resize(n * n * 3)
	var orm_data := PackedByteArray()
	orm_data.resize(n * n * 3)

	var panels := float(panels_per_tile)
	var can_stagger := stagger_rows and panels_per_tile % 2 == 0
	var gw := maxf(groove_width, 0.001)
	var corner := 0.5 - bolt_inset

	for y in n:
		@warning_ignore("integer_division")
		var sv_row := (y * streak / n) * n
		var sh_row := y * streak

		for x in n:
			var i := y * n + x
			var u := (float(x) + 0.5) / n
			var v := (float(y) + 0.5) / n

			var pv := v * panels
			var pu := u * panels
			if can_stagger and int(floorf(pv)) % 2 == 1:
				pu += 0.5
			var fu := fposmod(pu, 1.0)
			var fv := fposmod(pv, 1.0)

			var edge := minf(minf(fu, 1.0 - fu), minf(fv, 1.0 - fv))
			var groove := 1.0 - smoothstep(0.0, gw, edge)

			var ax := absf(fu - 0.5) - corner
			var ay := absf(fv - 0.5) - corner
			var bd := sqrt(ax * ax + ay * ay)
			var bolt := 1.0 - smoothstep(bolt_radius * 0.6, bolt_radius, bd)
			var slot := 1.0 - smoothstep(bolt_radius * 0.15, bolt_radius * 0.4, bd)

			@warning_ignore("integer_division")
			var sh_col := x * streak / n
			var sv := _ridge(scratch_v[sv_row + x]) * smoothstep(0.4, 0.85, wear_v[i] / 255.0)
			var sh := _ridge(scratch_h[sh_row + sh_col]) * smoothstep(0.4, 0.85, wear_h[i] / 255.0)
			var scratch := maxf(sv, sh) * scratch_amount

			var dirt := smoothstep(0.45, 0.85, grime[i] / 255.0) * grime_amount
			var grn := grain[i] / 255.0 - 0.5

			heights[i] = (
				-groove * _H_GROOVE
				+ bolt * _H_BOLT
				- slot * _H_SLOT
				- scratch * _H_SCRATCH
				+ grn * _H_GRAIN
			)

			var col := base_color.lerp(grime_color, dirt)
			col = col.lerp(groove_color, groove)
			col = col.lerp(bolt_color, bolt * 0.85)
			col = col.lerp(groove_color, slot * 0.4)
			col = col.lerp(scratch_color, scratch * 0.75)
			col = col * (1.0 + grn * 0.15)

			var rough := lerpf(base_roughness, 0.9, dirt)
			rough = lerpf(rough, base_roughness * 0.75, bolt * 0.5)
			rough = lerpf(rough, 0.2, scratch)
			rough += grn * 0.08

			var metal := lerpf(base_metallic, 0.1, dirt)
			metal = lerpf(metal, 1.0, scratch)

			var o := i * 3
			albedo_data[o] = _to_byte(col.r)
			albedo_data[o + 1] = _to_byte(col.g)
			albedo_data[o + 2] = _to_byte(col.b)
			orm_data[o] = _to_byte(1.0 - groove * 0.7 - slot * 0.3)
			orm_data[o + 1] = _to_byte(rough)
			orm_data[o + 2] = _to_byte(metal)

	return [
		_image_from(n, albedo_data),
		_image_from(n, orm_data),
		_image_from(n, _bake_normals(n, heights)),
	]


func _bake_normals(n: int, heights: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(n * n * 3)
	var texel_world := maxf(panel_size * panels_per_tile, 0.001) / float(n)
	var slope := 0.5 * _HEIGHT_WORLD / texel_world

	for y in n:
		var up := ((y - 1 + n) % n) * n
		var down := ((y + 1) % n) * n
		var mid := y * n
		for x in n:
			var dx := heights[mid + (x + 1) % n] - heights[mid + (x - 1 + n) % n]
			var dy := heights[down + x] - heights[up + x]
			var nrm := Vector3(-dx * slope, -dy * slope, 1.0).normalized()

			var o := (mid + x) * 3
			data[o] = _to_byte(nrm.x * 0.5 + 0.5)
			data[o + 1] = _to_byte(nrm.y * 0.5 + 0.5)
			data[o + 2] = _to_byte(nrm.z * 0.5 + 0.5)
	return data


func _image_from(n: int, data: PackedByteArray) -> Image:
	return Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)


func _make_noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_octaves = octaves
	return noise


func _noise_bytes(noise: FastNoiseLite, w: int, h: int) -> PackedByteArray:
	var img := noise.get_seamless_image(w, h)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


func _ridge(sample: int) -> float:
	var t := absf(float(sample) / 255.0 * 2.0 - 1.0)
	return pow(maxf(1.0 - t, 0.0), _SCRATCH_SHARPNESS)


func _to_byte(value: float) -> int:
	return clampi(int(roundf(value * 255.0)), 0, 255)

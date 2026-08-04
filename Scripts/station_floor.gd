extends MeshInstance3D
## Space-station deck plating on a flat plane. The whole material is generated
## at _ready(): albedo, a packed AO/roughness/metallic map and a normal map are
## baked into ImageTextures from seamless noise plus a little analytic geometry
## for the panel grooves and bolts. No image files, so every knob below is an
## inspector value.
##
## Detail is deliberately coarse. At the project's 64x64 render this floor is
## only about 45 pixels across, so a panel has to be several world units wide
## before its bolts survive down to the mip level that actually gets sampled.

# --- geometry -----------------------------------------------------------------

@export var plane_size := Vector2(8.0, 8.0)
## World units per deck panel. Panels are the unit everything else is measured
## against -- groove and bolt sizes below are fractions of one panel, so they
## follow when this changes.
@export var panel_size := 4.0
## Panels baked into a single texture repeat. Larger values pack more variation
## into one tile at the cost of resolution per panel.
@export_range(1, 8) var panels_per_tile := 2
## Offsets every other panel row by half a panel, the way real deck plating is
## laid. Needs an even panels_per_tile, otherwise the stagger would not line up
## across the texture seam and is skipped.
@export var stagger_rows := true

# --- texture ------------------------------------------------------------------

## Kept close to the floor's on-screen footprint on purpose. The deck is about
## 40 pixels wide at a 64x64 render, so anything past ~128 is detail that only
## the mip chain ever sees, and it averages back out to flat grey.
## Cost is O(n^2) in GDScript, paid once at _ready().
@export_range(64, 1024) var texture_resolution := 128
@export var noise_seed := 0

@export var base_color := Color("6a7183")
## Recessed seam between panels. Dark, because at this render size the groove is
## about one pixel wide and contrast is the only thing that makes it read.
@export var groove_color := Color("262b39")
@export var bolt_color := Color("929aab")
## Bare metal under a fresh gouge -- brighter and shinier than the surface.
@export var scratch_color := Color("bcc3d2")
@export var grime_color := Color("343a4a")

@export_range(0.0, 1.0) var grime_amount := 0.55
@export_range(0.0, 1.0) var scratch_amount := 0.6
@export_range(0.0, 1.0) var base_roughness := 0.45
@export_range(0.0, 1.0) var base_metallic := 0.6
@export_range(0.0, 4.0) var normal_strength := 1.0

## Groove and bolt dimensions, as fractions of one panel. These are large for
## the look they are imitating -- a 4 unit panel is ~20 pixels on screen, so a
## realistically thin seam would land under half a pixel and mip away to
## nothing. Everything here is sized to survive to about two pixels.
@export_range(0.001, 0.25) var groove_width := 0.055
@export_range(0.0, 0.4) var bolt_inset := 0.145
@export_range(0.0, 0.2) var bolt_radius := 0.105

# --- heightfield --------------------------------------------------------------

## Contributions to the heightfield, in abstract units. Nothing is displaced --
## this only exists to be differentiated into the normal map.
const _H_GROOVE := 0.55
const _H_BOLT := 0.35
const _H_SLOT := 0.20 ## Recess in the middle of a bolt head, i.e. the screw slot.
const _H_SCRATCH := 0.10
const _H_GRAIN := 0.06
## World depth of one height unit. Divides out the texel size when the normal
## map is built, so normal_strength keeps meaning the same thing when
## texture_resolution or panel_size changes.
const _HEIGHT_WORLD := 0.05
## Exponent on the ridge fold that turns noise into scratches. Higher = thinner.
const _SCRATCH_SHARPNESS := 14.0
## How far noise is squashed before being stretched back out, which is what
## makes scratches long and thin rather than blobby.
const _STREAK_RATIO := 12


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = plane_size
	mesh = plane
	material_override = _build_material()


func _build_material() -> StandardMaterial3D:
	var maps := _bake_maps(clampi(texture_resolution, 16, 2048))
	var tile_world := maxf(panel_size * panels_per_tile, 0.001)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = maps[0]
	# roughness, metallic and ao each multiply their texture sample, so the
	# scalars stay at 1.0 and the real values live in the packed map:
	# R = ambient occlusion, G = roughness, B = metallic.
	mat.roughness = 1.0
	mat.roughness_texture = maps[1]
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic = 1.0
	mat.metallic_texture = maps[1]
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.ao_enabled = true
	mat.ao_texture = maps[1]
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = true
	mat.normal_texture = maps[2]
	mat.normal_scale = normal_strength
	mat.uv1_scale = Vector3(plane_size.x / tile_world, plane_size.y / tile_world, 1.0)
	# A floor seen from a low iso angle is squashed far harder along one screen
	# axis than the other. Trilinear filtering picks its mip from the larger of
	# the two UV derivatives, which costs about a mip level and is enough to wipe
	# the panel seams out entirely. Anisotropic sampling is what keeps them.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Returns [albedo, ao/roughness/metallic, normal].
func _bake_maps(n: int) -> Array[ImageTexture]:
	@warning_ignore("integer_division")
	var streak := maxi(n / _STREAK_RATIO, 4)
	var grime := _noise_bytes(_make_noise(noise_seed + 1, 0.012, 4), n, n)
	var grain := _noise_bytes(_make_noise(noise_seed + 2, 0.35, 2), n, n)
	# Scratches come from noise generated into a squashed image and read back
	# stretched, which draws its features out into streaks. One pass per axis so
	# the floor is not scuffed in a single direction.
	var scratch_v := _noise_bytes(_make_noise(noise_seed + 3, 0.08, 3), n, streak)
	var scratch_h := _noise_bytes(_make_noise(noise_seed + 4, 0.08, 3), streak, n)
	# Keeps scratches in patches instead of evenly covering the deck. One mask
	# per axis, and deliberately not the same one: with a shared mask the two
	# streak fields are scuffed in the same places and every crossing reads as a
	# drawn plus sign rather than as wear.
	var wear_v := _noise_bytes(_make_noise(noise_seed + 5, 0.02, 2), n, n)
	var wear_h := _noise_bytes(_make_noise(noise_seed + 6, 0.023, 2), n, n)

	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var albedo_data := PackedByteArray()
	albedo_data.resize(n * n * 3)
	var orm_data := PackedByteArray()
	orm_data.resize(n * n * 3)

	var panels := float(panels_per_tile)
	# An odd panel count cannot stagger: row parity would flip across the tile
	# seam and the offset rows would not meet.
	var can_stagger := stagger_rows and panels_per_tile % 2 == 0
	var gw := maxf(groove_width, 0.001)
	var corner := 0.5 - bolt_inset

	for y in n:
		# Row offsets into the two squashed scratch images, hoisted out of the
		# inner loop. Both are deliberately integer divisions: they pick a source
		# row, and the truncation is what stretches the noise.
		@warning_ignore("integer_division")
		var sv_row := (y * streak / n) * n
		var sh_row := y * streak

		for x in n:
			var i := y * n + x
			var u := (float(x) + 0.5) / n
			var v := (float(y) + 0.5) / n

			# Position within the current panel.
			var pv := v * panels
			var pu := u * panels
			if can_stagger and int(floorf(pv)) % 2 == 1:
				pu += 0.5
			var fu := fposmod(pu, 1.0)
			var fv := fposmod(pv, 1.0)

			# Seam around the panel border.
			var edge := minf(minf(fu, 1.0 - fu), minf(fv, 1.0 - fv))
			var groove := 1.0 - smoothstep(0.0, gw, edge)

			# One bolt near each panel corner. Folding the panel into its own
			# quadrant turns four distance checks into one.
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
			var grn := grain[i] / 255.0 - 0.5 # -0.5 .. 0.5

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
			col = col.lerp(groove_color, slot * 0.4) # the screw slot itself
			col = col.lerp(scratch_color, scratch * 0.75)
			col = col * (1.0 + grn * 0.15)

			var rough := lerpf(base_roughness, 0.9, dirt) # grime is matte
			rough = lerpf(rough, base_roughness * 0.75, bolt * 0.5) # heads rub smooth
			rough = lerpf(rough, 0.2, scratch) # a fresh gouge is polished
			rough += grn * 0.08

			var metal := lerpf(base_metallic, 0.1, dirt) # dirt is not metal
			metal = lerpf(metal, 1.0, scratch)

			var o := i * 3
			albedo_data[o] = _to_byte(col.r)
			albedo_data[o + 1] = _to_byte(col.g)
			albedo_data[o + 2] = _to_byte(col.b)
			orm_data[o] = _to_byte(1.0 - groove * 0.7 - slot * 0.3)
			orm_data[o + 1] = _to_byte(rough)
			orm_data[o + 2] = _to_byte(metal)

	return [
		_texture_from(n, albedo_data),
		_texture_from(n, orm_data),
		_texture_from(n, _bake_normals(n, heights)),
	]


## Central differences over the heightfield, wrapped so the normal map tiles as
## seamlessly as the noise it came from.
func _bake_normals(n: int, heights: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(n * n * 3)
	# Height units per texel, in world terms -- this is what keeps the slope (and
	# so normal_strength) independent of texture_resolution.
	var texel_world := maxf(panel_size * panels_per_tile, 0.001) / float(n)
	var slope := 0.5 * _HEIGHT_WORLD / texel_world

	for y in n:
		var up := ((y - 1 + n) % n) * n
		var down := ((y + 1) % n) * n
		var mid := y * n
		for x in n:
			var dx := heights[mid + (x + 1) % n] - heights[mid + (x - 1 + n) % n]
			var dy := heights[down + x] - heights[up + x]
			# OpenGL-style (Y+) tangent space, which is what Godot expects. Image
			# y grows downward, hence the second negation.
			var nrm := Vector3(-dx * slope, -dy * slope, 1.0).normalized()

			var o := (mid + x) * 3
			data[o] = _to_byte(nrm.x * 0.5 + 0.5)
			data[o + 1] = _to_byte(nrm.y * 0.5 + 0.5)
			data[o + 2] = _to_byte(nrm.z * 0.5 + 0.5)
	return data


func _texture_from(n: int, data: PackedByteArray) -> ImageTexture:
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	# Mipmaps matter more than usual here: the floor is minified roughly 6x at
	# 64x64, and without them the bolts and scratches shimmer.
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_octaves = octaves
	return noise


func _noise_bytes(noise: FastNoiseLite, w: int, h: int) -> PackedByteArray:
	# get_seamless_image() wraps on both axes and returns synchronously, unlike
	# NoiseTexture2D which generates on a thread and hands back null until ready.
	var img := noise.get_seamless_image(w, h)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


## Folds a 0..255 noise sample around its midpoint so the zero crossings become
## thin bright lines: the scratches.
func _ridge(sample: int) -> float:
	var t := absf(float(sample) / 255.0 * 2.0 - 1.0)
	return pow(maxf(1.0 - t, 0.0), _SCRATCH_SHARPNESS)


func _to_byte(value: float) -> int:
	return clampi(int(roundf(value * 255.0)), 0, 255)

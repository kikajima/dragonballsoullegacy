extends Control

const DMI = preload("res://core/assets/dmi_sprite_sheet.gd")
const SOURCE_DIR := "res://assets/vendor/hu2/Icons/Characters"
const GBA_SOURCE := "res://assets/sprites/characters/goku/source/goku_buus_fury_source.png"
const GBA_CHARACTERS := "res://generated/sprites/characters/manifest.json"
const DIRECTIONS := [&"down", &"left", &"right", &"up"]
var sources: OptionButton
var animations: OptionButton
var direction: OptionButton
var palette: OptionButton
var replacement: ColorPickerButton
var status: Label
var preview_note: Label
var preview: AnimatedSprite2D
var original: SpriteFrames
var generated: SpriteFrames
var colors: Array[Color] = []
var mappings: Dictionary = {}
var provenance: Dictionary = {}
var paths: Array[String] = []
var source_labels: Array[String] = []
var search: LineEdit
var origin_filter: OptionButton
var active_source := -1
var gba_view: OptionButton

func _ready() -> void:
	get_window().title = "Oficina de sprites — catálogo HU2 / GBA"
	get_window().content_scale_size = Vector2i(800, 450)
	theme = Theme.new()
	theme.default_font_size = 10
	var background := ColorRect.new()
	background.color = Color("202a38")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.position = Vector2(12, 8)
	panel.size = Vector2(340, 430)
	panel.add_theme_constant_override("separation", 5)
	add_child(panel)
	var heading := Label.new()
	heading.text = "Oficina de sprites — protótipo"
	panel.add_child(heading)
	search = LineEdit.new()
	search.placeholder_text = "Buscar personagem: Roshi, Goku, Bulma…"
	panel.add_child(search)
	origin_filter = OptionButton.new()
	for label in ["Todas as fontes", "GBA", "HU2"]:
		origin_filter.add_item(label)
	panel.add_child(origin_filter)
	sources = OptionButton.new()
	for file in DirAccess.get_files_at(SOURCE_DIR):
		if file.ends_with(".dmi"):
			paths.append(SOURCE_DIR.path_join(file))
			sources.add_item("HU2 — " + file.get_basename())
	if FileAccess.file_exists(GBA_CHARACTERS):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(GBA_CHARACTERS))
		if manifest is Dictionary:
			for character in manifest.get("characters", []):
				paths.append("res://generated/sprites/characters/" + String(character.image).get_basename() + ".json")
				sources.add_item("GBA — %s [%s]" % [character.label, String(character.source).get_slice("/", 0)])
	sources.fit_to_longest_item = false
	sources.clip_text = true
	sources.custom_minimum_size.x = 260
	for item in sources.item_count:
		source_labels.append(sources.get_item_text(item))
		sources.set_item_metadata(item, item)
	sources.select(-1)
	sources.text = "Escolha um personagem (%d fontes)" % paths.size()
	panel.add_child(sources)
	gba_view = OptionButton.new()
	for label in ["Poses revisadas", "Quadros pendentes de revisão", "Folha completa / blocos"]:
		gba_view.add_item(label)
	gba_view.disabled = true
	panel.add_child(gba_view)
	var row := HBoxContainer.new()
	panel.add_child(row)
	animations = OptionButton.new()
	animations.fit_to_longest_item = false
	animations.clip_text = true
	animations.custom_minimum_size.x = 170
	row.add_child(animations)
	direction = OptionButton.new()
	for label in ["Baixo", "Esquerda", "Direita", "Cima"]:
		direction.add_item(label)
	row.add_child(direction)
	palette = OptionButton.new()
	panel.add_child(palette)
	replacement = ColorPickerButton.new()
	replacement.text = "Nova cor"
	replacement.edit_alpha = false
	panel.add_child(replacement)
	var apply := Button.new()
	apply.text = "Trocar cor em todas as poses"
	apply.pressed.connect(_apply_color)
	panel.add_child(apply)
	var reset := Button.new()
	reset.text = "Restaurar cores originais"
	reset.pressed.connect(func(): mappings.clear(); _rebuild())
	panel.add_child(reset)
	var export_button := Button.new()
	export_button.text = "Exportar PNG + SpriteFrames + receita"
	export_button.pressed.connect(_export)
	panel.add_child(export_button)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 10)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	preview = AnimatedSprite2D.new()
	preview.position = Vector2(580, 210)
	preview.scale = Vector2(4, 4)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(preview)
	var note := Label.new()
	preview_note = note
	note.position = Vector2(420, 350)
	note.add_theme_font_size_override("font_size", 10)
	note.text = "1. Busque o personagem\n2. Escolha a fonte na lista\n3. Selecione pose e direção"
	add_child(note)
	sources.item_selected.connect(func(index): _load_source(int(sources.get_item_metadata(index))))
	search.text_changed.connect(func(_text): _filter_sources())
	origin_filter.item_selected.connect(func(_index): _filter_sources())
	gba_view.item_selected.connect(func(_index):
		if active_source >= 0 and paths[active_source].ends_with(".json"):
			_load_gba_character(paths[active_source]))
	animations.item_selected.connect(func(_index): _update_directions(); _play())
	direction.item_selected.connect(func(_index): _play())
	palette.item_selected.connect(func(index): replacement.color = colors[index])
	status.text = "Escolha uma fonte acima para começar. GBA e HU2 estão na mesma biblioteca."
	if not FileAccess.file_exists(GBA_CHARACTERS):
		status.text = "Catálogo GBA ausente: execute python tools/map_sprite_library.py --refresh-reviews"

func _filter_sources() -> void:
	sources.clear()
	for index in paths.size():
		var label := source_labels[index]
		if not search.text.to_lower() in label.to_lower():
			continue
		if origin_filter.selected == 1 and not paths[index].ends_with(".json"):
			continue
		if origin_filter.selected == 2 and not paths[index].ends_with(".dmi"):
			continue
		sources.add_item(label)
		sources.set_item_metadata(sources.item_count - 1, index)
	sources.select(-1)
	sources.text = "Escolha um personagem (%d resultados)" % sources.item_count

func _update_directions() -> void:
	if provenance.get("kind", "") != "gba_character" or animations.selected < 0:
		return
	var state := str(animations.get_item_metadata(animations.selected))
	direction.clear()
	for facing in ["down", "left", "right", "up", "side", "single"]:
		if original.has_animation(StringName(state + "_" + facing)):
			direction.add_item({"down":"Baixo", "left":"Esquerda", "right":"Direita", "up":"Cima", "side":"Lateral", "single":"Única"}[facing])
			direction.set_item_metadata(direction.item_count - 1, facing)
	direction.disabled = direction.item_count == 0

func _load_source(index: int) -> void:
	active_source = index
	for item in sources.item_count:
		if int(sources.get_item_metadata(item)) == index:
			sources.select(item)
			break
	gba_view.select(0)
	gba_view.disabled = not paths[index].ends_with(".json")
	if paths[index].ends_with(".json"):
		_load_gba_character(paths[index])
		return
	direction.disabled = false
	direction.clear()
	for label in ["Baixo", "Esquerda", "Direita", "Cima"]:
		direction.add_item(label)
	preview_note.text = "Prévia 4×\nCor global, sem camadas"
	preview.scale = Vector2(4, 4)
	var source_sheet = DMI.load_file(paths[index])
	if source_sheet == null:
		status.text = "Falha ao abrir o DMI."
		return
	var sheet = DMI.new()
	sheet.states = source_sheet.states.duplicate(true)
	sheet.texture = source_sheet.texture
	sheet.frame_size = source_sheet.frame_size
	sheet._sheet_columns = source_sheet._sheet_columns
	original = SpriteFrames.new()
	original.remove_animation(&"default")
	animations.clear()
	mappings.clear()
	provenance = {"dmi": paths[index], "cell_size": [sheet.frame_size.x, sheet.frame_size.y]}
	var state_names: Array = sheet.states.keys()
	# Catalog keeps duplicate DMI states as separate variants. The gameplay
	# reader intentionally keeps its previous last-state-wins behavior.
	var catalog_path := "res://generated/sprites/catalog/catalog.json"
	if FileAccess.file_exists(catalog_path):
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if catalog is Dictionary:
			for entry in catalog.get("entries", []):
				if entry.kind != "dmi" or String(entry.path).replace("\\", "/") != ProjectSettings.globalize_path(paths[index]).replace("\\", "/"):
					continue
				state_names.clear()
				for state in entry.states:
					var id: String = state.id
					state_names.append(id)
					var first: Array = state.frames[0].rect
					var delays := PackedFloat32Array()
					for frame in state.frames:
						if frame.direction == state.frames[0].direction:
							delays.append(float(frame.duration_seconds) * 10.0)
					sheet.states[id] = {"frames": int(state.frame_count), "dirs": int(state.directions), "delay": delays,
						"tile_start": int(first[1]) / sheet.frame_size.y * sheet._sheet_columns + int(first[0]) / sheet.frame_size.x}
				break
	for state in state_names:
		animations.add_item("idle" if state == "" else state)
		animations.set_item_metadata(animations.item_count - 1, state)
		for facing in DIRECTIONS:
			var name := StringName("%s_%s" % ["idle" if state == "" else state, facing])
			original.add_animation(name)
			original.set_animation_speed(name, 10.0)
			for frame in sheet.get_frame_count(state):
				original.add_frame(name, sheet.get_frame_texture(state, facing, frame), sheet.get_frame_delay(state, frame))
	if paths[index].get_file() == "Goku.dmi" and FileAccess.file_exists(GBA_SOURCE):
		_add_gba_pose()
	_collect_palette()
	for item in animations.item_count:
		if str(animations.get_item_metadata(item)) in ["", "idle#0"]:
			animations.select(item)
			break
	_rebuild()
	status.text = "Fonte carregada. Escolha pose, direção e cor."

func _load_gba_character(path: String) -> void:
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not record is Dictionary:
		status.text = "Não foi possível abrir o personagem GBA."
		return
	var image := Image.load_from_file(path.get_basename() + ".png")
	if image == null:
		status.text = "Recorte GBA ausente. Gere novamente o catálogo."
		return
	if gba_view.selected == 0 and record.get("poses", []).is_empty():
		gba_view.select(1)
	var shown_poses: Array = record.get("poses", [])
	if gba_view.selected == 1:
		shown_poses = []
		for region in record.get("unreviewed_regions", []):
			shown_poses.append({"name":region.id,"frames":[{"direction":"single","frame":0,"rect":region.rect}]})
	elif gba_view.selected == 2:
		shown_poses = []
	original = SpriteFrames.new()
	original.remove_animation(&"default")
	animations.clear()
	mappings.clear()
	direction.disabled = true
	preview_note.text = "Bloco do personagem\nPrévia ajustada à área"
	var max_size := Vector2i.ONE
	for block in record.blocks:
		var r: Array = block.atlas_rect
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var name := StringName("bloco_%02d" % (animations.item_count + 1))
		animations.add_item("%s (poses a mapear)" % name)
		animations.set_item_metadata(animations.item_count - 1, name)
		original.add_animation(name)
		original.set_animation_loop(name, false)
		original.add_frame(name, ImageTexture.create_from_image(image.get_region(rect)))
		max_size.x = maxi(max_size.x, rect.size.x)
		max_size.y = maxi(max_size.y, rect.size.y)
	if not shown_poses.is_empty():
		original.clear_all()
		original.remove_animation(&"default")
		animations.clear()
		max_size = Vector2i.ONE
		for pose in shown_poses:
			animations.add_item(("[REVISAR] " if gba_view.selected == 1 else "") + pose.name)
			animations.set_item_metadata(animations.item_count - 1, pose.name)
			for frame in pose.frames:
				var name := StringName("%s_%s" % [pose.name, frame.direction])
				if not original.has_animation(name):
					original.add_animation(name)
					original.set_animation_speed(name, 7.0)
				var r: Array = frame.rect
				var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
				original.add_frame(name, ImageTexture.create_from_image(image.get_region(rect)))
				max_size.x = maxi(max_size.x, rect.size.x)
				max_size.y = maxi(max_size.y, rect.size.y)
	provenance = {"kind": "gba_character", "character": record.label,
		"source": record.source_path, "source_sha256": record.source_sha256,
		"blocks": record.blocks, "cell_size": [max_size.x, max_size.y],
		"mapping_status": "character_separated_poses_pending"}
	if gba_view.selected == 0 and not shown_poses.is_empty():
		provenance["mapping_status"] = "reviewed_poses_timing_unmeasured"
		provenance["poses"] = record.poses
		preview_note.text = "Poses revisadas\nGBA: 7 fps ilustrativos"
	elif gba_view.selected == 1:
		provenance["mapping_status"] = "unreviewed_regions_not_animations"
		preview_note.text = "Recorte pendente: pode ser texto ou fragmento.\nAção, direção e sequência não identificadas."
	provenance["view"] = gba_view.selected
	provenance["shown_poses"] = shown_poses
	_update_directions()
	_collect_palette()
	_rebuild()
	status.text = "%s: blocos estáticos; poses e direções ainda a mapear." % record.label
	if gba_view.selected == 1:
		status.text = "%s: recortes pendentes, não animações confirmadas." % record.label
	if provenance.mapping_status == "reviewed_poses_timing_unmeasured":
		status.text = "%s: %d poses disponíveis. Escolha pose e direção." % [record.label, record.poses.size()]
	status.text += "\n%d poses revisadas · %d regiões pendentes. Mapeamento parcial." % [record.get("poses", []).size(), record.get("unreviewed_regions", []).size()]

func _add_gba_pose() -> void:
	var image := Image.load_from_file(GBA_SOURCE)
	if image == null or image.get_width() < 1152 or image.get_height() < 160:
		return
	animations.add_item("spirit_charge (Buu's Fury)")
	animations.set_item_metadata(animations.item_count - 1, "spirit_charge")
	for row in range(4):
		var cell := image.get_region(Rect2i(1120, 32 + row * 32, 32, 32))
		cell.convert(Image.FORMAT_RGBA8)
		var key := cell.get_pixel(0, 0)
		for y in range(32):
			for x in range(32):
				if cell.get_pixel(x, y).is_equal_approx(key):
					cell.set_pixel(x, y, Color.TRANSPARENT)
		var name := StringName("spirit_charge_%s" % DIRECTIONS[row])
		original.add_animation(name)
		original.add_frame(name, ImageTexture.create_from_image(cell))
	provenance["gba_pose"] = {"source": GBA_SOURCE, "column": 35, "rows": [1, 2, 3, 4], "credit": "SPYN"}

func _collect_palette() -> void:
	colors.clear()
	palette.clear()
	var seen := {}
	for name in original.get_animation_names():
		for frame in original.get_frame_count(name):
			var image := original.get_frame_texture(name, frame).get_image()
			for y in image.get_height():
				for x in image.get_width():
					var color := image.get_pixel(x, y)
					if color.a > 0 and not seen.has(color.to_rgba32()):
						seen[color.to_rgba32()] = true
						colors.append(color)
	for color in colors:
		var swatch := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		swatch.fill(color)
		palette.add_icon_item(ImageTexture.create_from_image(swatch), "Cor original #" + color.to_html(false))
	if not colors.is_empty():
		replacement.color = colors[0]

func _apply_color() -> void:
	if colors.is_empty():
		return
	mappings[colors[palette.selected].to_html()] = replacement.color.to_html()
	_rebuild()

func _rebuild() -> void:
	if original == null:
		return
	generated = SpriteFrames.new()
	generated.remove_animation(&"default")
	for name in original.get_animation_names():
		generated.add_animation(name)
		generated.set_animation_speed(name, original.get_animation_speed(name))
		generated.set_animation_loop(name, original.get_animation_loop(name))
		for frame in original.get_frame_count(name):
			var image := original.get_frame_texture(name, frame).get_image()
			image.convert(Image.FORMAT_RGBA8)
			for y in image.get_height():
				for x in image.get_width():
					var color := image.get_pixel(x, y)
					if color.a > 0 and mappings.has(color.to_html()):
						image.set_pixel(x, y, Color(mappings[color.to_html()]))
			generated.add_frame(name, ImageTexture.create_from_image(image), original.get_frame_duration(name, frame))
	preview.sprite_frames = generated
	_play()

func _play() -> void:
	if generated == null or animations.selected < 0:
		return
	var state: String = str(animations.get_item_metadata(animations.selected))
	if provenance.get("kind", "") == "gba_character":
		var animation := state
		if direction.item_count > 0:
			animation += "_" + str(direction.get_item_metadata(direction.selected))
		preview.play(StringName(animation))
		var texture := generated.get_frame_texture(StringName(animation), 0)
		var factor := minf(4.0, 165.0 / maxf(texture.get_width(), texture.get_height()))
		if factor >= 1.0:
			factor = floorf(factor)
		preview.scale = Vector2.ONE * factor
		return
	preview.play(StringName("%s_%s" % ["idle" if state == "" else state, DIRECTIONS[direction.selected]]))

func _export() -> void:
	if generated == null:
		return
	var export_frames := generated
	if provenance.get("mapping_status", "") == "unreviewed_regions_not_animations":
		export_frames = SpriteFrames.new()
		export_frames.remove_animation(&"default")
		export_frames.add_animation(preview.animation)
		export_frames.set_animation_loop(preview.animation, false)
		export_frames.add_frame(preview.animation, generated.get_frame_texture(preview.animation, 0))
	var folder := "res://generated/sprites/%s_%s" % [source_labels[active_source].validate_filename(), str(Time.get_unix_time_from_system()).replace(".", "_")]
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		status.text = "Não foi possível criar a pasta de exportação."
		return
	var width: int = int(provenance.cell_size[0])
	var height: int = int(provenance.cell_size[1])
	if export_frames != generated:
		var texture := export_frames.get_frame_texture(preview.animation, 0)
		width = texture.get_width()
		height = texture.get_height()
	var count := 0
	for name in export_frames.get_animation_names():
		count += export_frames.get_frame_count(name)
	var columns := 1 if provenance.get("kind", "") == "gba_character" else 16
	var atlas := Image.create(width * columns, height * ceili(float(count) / columns), false, Image.FORMAT_RGBA8)
	var entries: Array = []
	var index := 0
	for name in export_frames.get_animation_names():
		for frame in export_frames.get_frame_count(name):
			var image := export_frames.get_frame_texture(name, frame).get_image()
			var point := Vector2i((index % columns) * width, (index / columns) * height)
			atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), point)
			entries.append({"animation": name, "frame": frame, "rect": [point.x, point.y, image.get_width(), image.get_height()], "duration": export_frames.get_frame_duration(name, frame), "fps": export_frames.get_animation_speed(name)})
			index += 1
	error = atlas.save_png(folder.path_join("spritesheet.png"))
	if error == OK:
		error = ResourceSaver.save(export_frames, folder.path_join("animations.tres"))
	var recipe := FileAccess.open(folder.path_join("recipe.json"), FileAccess.WRITE)
	if error != OK or recipe == null:
		status.text = "Exportação incompleta; erro ao gravar arquivos."
		return
	recipe.store_string(JSON.stringify({"version": 1, "sources": provenance, "palette": mappings, "frames": entries}, "\t"))
	status.text = "Exportado: " + folder.trim_prefix("res://")

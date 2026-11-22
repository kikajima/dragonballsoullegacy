extends SceneTree

# Prints a DMI's states and renders them in a grid (8 per row, 2 px gap,
# on magenta so transparency shows) to study tiles.
# Usage: Godot --headless --path . --script res://tools/world/dmi_contact_sheet.gd -- <res dmi> <out.png> [filter]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dmi := DmiSpriteSheet.load_file(args[0])
	var filter := args[2] if args.size() > 2 else ""
	var states: Array = []
	if dmi == null:
		push_error("cannot load " + args[0])
		quit(1)
		return
	for state in dmi.states.keys():
		if filter == "" or String(state).contains(filter):
			states.append(state)
	var cols := 8
	var rows := ceili(states.size() / float(cols))
	var sheet := Image.create(cols * 34, rows * 34, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 0, 1))
	var line := ""
	for i in states.size():
		var img := dmi.get_frame_texture(states[i], &"down", 0).get_image()
		img.convert(Image.FORMAT_RGBA8)
		var region := Rect2i(Vector2i.ZERO, img.get_size().min(Vector2i(32, 32)))
		sheet.fill_rect(Rect2i(Vector2i(i % cols, i / cols) * 34, Vector2i(32, 32)), Color(0.2, 0.2, 0.2))
		sheet.blend_rect(img, region, Vector2i(i % cols, i / cols) * 34)
		line += "%s | " % states[i]
		if i % cols == cols - 1:
			print("row %d: %s" % [i / cols, line])
			line = ""
	if line != "":
		print("row %d: %s" % [rows - 1, line])
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(args[1])
	quit()

extends SceneTree

# Prints each DMI state's opaque bounding box and coverage (to see which
# side or corner an edge tile covers).
# Usage: Godot --headless --path . --script res://tools/world/dmi_alpha_bounds.gd -- <res dmi>

func _init() -> void:
	var dmi := DmiSpriteSheet.load_file(OS.get_cmdline_user_args()[0])
	for state in dmi.states.keys():
		var img := dmi.get_frame_texture(state, &"down", 0).get_image()
		img.convert(Image.FORMAT_RGBA8)
		var used := img.get_used_rect()
		var count := 0
		var grid := ""
		for gy in 4:
			for gx in 4:
				var n := 0
				for y in range(gy * 8, gy * 8 + 8):
					for x in range(gx * 8, gx * 8 + 8):
						if img.get_pixel(x, y).a > 0.5:
							n += 1
				count += n
				grid += "#" if n > 40 else ("+" if n > 8 else ("." if n > 0 else " "))
			grid += "/"
		print("%-14s used=%s cover=%3d%% [%s]" % [state, used, count * 100 / 1024, grid])
	quit()

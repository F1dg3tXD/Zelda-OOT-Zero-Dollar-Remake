extends PanelContainer

@onready var icon: TextureRect = %Icon
@onready var title: Label = %titleLabel
@onready var time: Label = %timeLabel

var save_id := ""
var is_empty := false
var is_disabled := false

func _ready():
	if title == null:
		push_error("Title label not found! Check node path.")
	if time == null:
		push_error("Time label not found! Check node path.")
	if icon == null:
		push_error("Icon not found! Check node path.")

func setup(data: Dictionary, empty := false, disabled := false):
	if not is_node_ready():
		await ready  # 🔥 ensures @onready vars exist

	is_empty = empty
	is_disabled = disabled
	save_id = data.get("id", "")

	if is_disabled:
		title.text = data.get("title", "Unavailable")
		time.text = ""
		modulate = Color(1,1,1,0.3)
		return

	if is_empty:
		title.text = "Empty"
		time.text = ""
		icon.texture = preload("res://addons/godot_xmb/assets/placeholder_icon.png")
	else:
		var game_title = data.get("game_title", str(ProjectSettings.get_setting("application/config/name", "Untitled Game")))
		var save_type = "Autosave" if str(data.get("save_type", "manual")) == "autosave" else "Manual"
		title.text = "%s: %s" % [game_title, save_type]
		
		var timestamp = data.get("timestamp", "")
		var _xmb: Node = get_node_or_null("/root/XMBSave")
		var playtime: String = str(data.get("playtime_text", ""))
		if playtime == "" and _xmb != null and _xmb.has_method("format_playtime"):
			playtime = str(_xmb.format_playtime(float(data.get("playtime_seconds", 0.0))))
		if timestamp != "":
			time.text = "%s - %s" % [timestamp, playtime]
		else:
			time.text = playtime

		var icon_path = "user://saves/%s/icon.png" % save_id
		if FileAccess.file_exists(icon_path):
			var image := Image.load_from_file(icon_path)
			if image != null and not image.is_empty():
				icon.texture = ImageTexture.create_from_image(image)

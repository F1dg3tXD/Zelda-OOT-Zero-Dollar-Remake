extends CanvasLayer

## Asks the player how autosaves should be stored the first time an autosave trigger
## fires. Returns the chosen mode: "overwrite" (a single dedicated autosave slot that
## is replaced every time) or "separate" (a brand-new autosave slot per save; old
## autosaves are trimmed to make room for new ones).
##
## Hand the result to XMBSave.set_autosave_mode(), which persists it in user:// so the
## question is only ever asked once. The autosave trigger example does this for you.

signal mode_selected(mode: String)

var _result := ""


func _ready() -> void:
	%OverwriteButton.grab_focus()


func _on_overwrite_button_pressed() -> void:
	_result = "overwrite"
	mode_selected.emit(_result)


func _on_separate_button_pressed() -> void:
	_result = "separate"
	mode_selected.emit(_result)


func prompt() -> String:
	await mode_selected
	queue_free()
	return _result

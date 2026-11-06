extends SceneTree

const TOOLBAR_SCENE := preload("res://scenes/anatomy/anatomy_toolbar.tscn")
const BROWSER_SCENE := preload("res://scenes/anatomy/anatomy_browser_panel.tscn")

var failures: Array[String] = []
var focus_preset := StringName()


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var toolbar = TOOLBAR_SCENE.instantiate()
	toolbar.focus_requested.connect(func(preset: StringName) -> void: focus_preset = preset)
	root.add_child(toolbar)
	var browser = BROWSER_SCENE.instantiate()
	root.add_child(browser)
	await process_frame

	require(toolbar.body_button != null, "Authored toolbar must expose its Body button")
	require(toolbar.cartilage_button != null, "Authored toolbar must expose its Cartilage button")
	require(toolbar.get_node("Margin/Rows/LayerRow").get_child_count() == 7, "Authored toolbar must contain all seven layer toggles")
	toolbar.get_node("Margin/Rows/ViewRow/HeadButton").pressed.emit()
	require(focus_preset == &"head", "Authored camera-view buttons must emit their configured preset")

	require(browser.get_node_or_null("Margin/Column/SearchInput") is LineEdit, "Authored anatomy browser must contain its search input")
	require(browser.get_node_or_null("Margin/Column/SearchResults") is Tree, "Authored anatomy browser must contain its result tree")
	require(browser.get_node_or_null("Margin/Column/Actions/WorkoutToggleButton") is Button, "Authored anatomy browser must contain its heatmap control")
	require(browser.get_node("Margin/Column/Actions").get_child_count() == 5, "Authored anatomy browser must contain all five actions")

	if failures.is_empty():
		print("Authored UI scenes passed: browser and toolbar are editor-visible")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

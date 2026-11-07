class_name DemoteDialog
extends Window

## Demote a council-promoted exercise back to catalog-only (the inverse of
## the council's Promote; see src/exercises/demotion.py). Opened from the
## Kinematic Definition Studio. Original, hand-built exercises aren't listed.

signal demoted(report: Dictionary)

const STRETCH_REASON := "It is a stretch. BodySim models muscles moving or holding a load, so a stretch's profile is meaningless."

@onready var exercise_list: ItemList = %ExerciseList
@onready var reason_input: TextEdit = %ReasonInput
@onready var status_label: Label = %DemoteStatusLabel
@onready var demote_button: Button = %DemoteButton
@onready var close_button: Button = %DemoteCloseButton

var exercises: Array = []
var armed_id := ""


func _ready() -> void:
	close_requested.connect(hide)
	close_button.pressed.connect(hide)
	demote_button.pressed.connect(_on_demote_pressed)
	exercise_list.item_selected.connect(_on_selected)
	reason_input.text_changed.connect(disarm)


func open() -> void:
	refresh()
	popup_centered(Vector2i(820, 580))


func refresh() -> void:
	disarm()
	exercise_list.clear()
	var result := ReviewRevisionStore.list_demotable()
	exercises = result.get("exercises", [])
	if not result.get("ok", false):
		set_status(" ".join(result.get("errors", ["Could not list promoted exercises."])), true)
		return
	for entry in exercises:
		var stretch: bool = entry.get("category", "") == "stretching"
		var promoted_on := Time.get_datetime_string_from_unix_time(int(entry.get("promoted_at_unix", 0))).left(10)
		exercise_list.add_item("%s%s  ·  %s  ·  promoted %s" % ["STRETCH · " if stretch else "", entry.get("name", ""), entry.get("exercise_id", ""), promoted_on])
		if stretch:
			exercise_list.set_item_custom_fg_color(exercise_list.item_count - 1, Color("e3aa57"))
	set_status("%d council-promoted exercise(s). Stretches are marked." % exercises.size() if not exercises.is_empty() else "No council-promoted exercises to demote.", false)


func selected_entry() -> Dictionary:
	var selected := exercise_list.get_selected_items()
	return exercises[selected[0]] if not selected.is_empty() else {}


func _on_selected(_index: int) -> void:
	disarm()
	var entry := selected_entry()
	if entry.get("category", "") == "stretching" and reason_input.text.strip_edges().is_empty():
		reason_input.text = STRETCH_REASON


## Demoting takes two clicks: the first arms the button for the selected exercise.
func _on_demote_pressed() -> void:
	var entry := selected_entry()
	if entry.is_empty():
		return set_status("Select an exercise to demote.", true)
	var reason := reason_input.text.strip_edges()
	if reason.is_empty():
		return set_status("Give a reason; it is kept in the audit trail.", true)
	var exercise_id := String(entry.get("exercise_id", ""))
	if armed_id != exercise_id:
		armed_id = exercise_id
		demote_button.text = "Confirm: demote %s" % entry.get("name", exercise_id)
		return set_status("This removes it from the visualizer. Its revision can't be promoted again; a re-authored one can.", false)
	var report := ReviewRevisionStore.demote(exercise_id, reason)
	disarm()
	if not report.get("ok", false):
		return set_status("Demotion blocked: %s" % " ".join(report.get("errors", [])), true)
	reason_input.text = ""
	refresh()
	set_status("Demoted %s; %s is catalog-only again. Commit the data and run tools/web/deploy_pages.sh to update the live demo." % [
		exercise_id, String(report.get("source_catalog_id", "")).trim_prefix("catalog.free_exercise_db.")], false)
	demoted.emit(report)


func disarm() -> void:
	armed_id = ""
	demote_button.text = "Demote selected"


func set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("ff7676") if is_error else Color("a9bdd0")

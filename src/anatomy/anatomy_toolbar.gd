class_name AnatomyToolbar
extends PanelContainer

signal body_visibility_changed(visible: bool)
signal muscle_visibility_changed(visible: bool)
signal bone_visibility_changed(visible: bool)
signal cartilage_visibility_changed(visible: bool)
signal connective_visibility_changed(visible: bool)
signal superficial_visibility_changed(visible: bool)
signal deep_visibility_changed(visible: bool)
signal focus_requested(preset: StringName)

@onready var body_button: Button = %BodyButton
@onready var muscle_button: Button = %MuscleButton
@onready var bone_button: Button = %BoneButton
@onready var cartilage_button: Button = %CartilageButton
@onready var connective_button: Button = %ConnectiveButton
@onready var superficial_button: Button = %SuperficialButton
@onready var deep_button: Button = %DeepButton


func _ready() -> void:
	body_button.toggled.connect(func(enabled: bool) -> void: body_visibility_changed.emit(enabled))
	muscle_button.toggled.connect(func(enabled: bool) -> void: muscle_visibility_changed.emit(enabled))
	bone_button.toggled.connect(func(enabled: bool) -> void: bone_visibility_changed.emit(enabled))
	cartilage_button.toggled.connect(func(enabled: bool) -> void: cartilage_visibility_changed.emit(enabled))
	connective_button.toggled.connect(func(enabled: bool) -> void: connective_visibility_changed.emit(enabled))
	superficial_button.toggled.connect(func(enabled: bool) -> void: superficial_visibility_changed.emit(enabled))
	deep_button.toggled.connect(func(enabled: bool) -> void: deep_visibility_changed.emit(enabled))
	for button in $Margin/Rows/ViewRow.get_children():
		if button is Button and button.has_meta("preset"):
			button.pressed.connect(
				func() -> void: focus_requested.emit(StringName(button.get_meta("preset")))
			)

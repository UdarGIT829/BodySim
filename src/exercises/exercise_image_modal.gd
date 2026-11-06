class_name ExerciseImageModal
extends Window

const MEDIA_MANIFEST_PATH := "res://data/exercises/sources/free_exercise_db_media.json"

@onready var heading_label: Label = %HeadingLabel
@onready var source_label: Label = %SourceLabel
@onready var first_image: TextureRect = %FirstImage
@onready var second_image: TextureRect = %SecondImage
@onready var message_label: Label = %MessageLabel
@onready var attribution_label: Label = %AttributionLabel
@onready var close_button: Button = %CloseButton

var media_by_exercise: Dictionary = {}
var current_exercise_id := ""

## Web builds don't pack the demonstration photos (they would add ~580 MB of
## imported textures). Instead each JPG is fetched on demand from a "photos/"
## folder next to index.html (see tools/web/stage_web_photos.py), decoded, and
## cached for the session.
const WEB_PHOTO_DIR := "photos/"
var _web_texture_cache: Dictionary = {}   # source_path -> Texture2D
var _web_request_serial := 0              # invalidates responses for a closed/changed popup
var _web_pending := 0                     # downloads still outstanding for the current popup


func _ready() -> void:
	load_media_manifest()
	close_requested.connect(hide)
	close_button.pressed.connect(hide)


func load_media_manifest(path: String = MEDIA_MANIFEST_PATH) -> bool:
	media_by_exercise.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ExerciseImageModal: Unable to open media manifest %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("ExerciseImageModal: Media manifest must be an array")
		return false
	for value in parsed:
		if value is Dictionary and value.has("exercise_id"):
			media_by_exercise[String(value["exercise_id"])] = value
	return true


func show_exercise(exercise_id: String, display_name: String) -> bool:
	if not media_by_exercise.has(exercise_id):
		return false
	current_exercise_id = exercise_id
	var entry: Dictionary = media_by_exercise[exercise_id]
	heading_label.text = display_name
	source_label.text = "Demonstration images · %s" % entry.get("source_name", "free-exercise-db")
	first_image.texture = null
	second_image.texture = null
	var image_controls: Array[TextureRect] = [first_image, second_image]
	var images: Array = entry.get("images", [])
	var loaded_count := 0
	if OS.has_feature("web"):
		loaded_count = _show_web_images(images, image_controls)
	else:
		for index in range(mini(images.size(), image_controls.size())):
			var image_record: Dictionary = images[index]
			var texture := load(String(image_record.get("resource_path", ""))) as Texture2D
			if texture != null:
				image_controls[index].texture = texture
				loaded_count += 1
		message_label.visible = loaded_count == 0
		message_label.text = "No local demonstration images are available." if loaded_count == 0 else ""
	attribution_label.text = "Source: free-exercise-db · %s · %s" % [
		entry.get("source_id", "unknown record"),
		entry.get("license", "license unknown"),
	]
	popup_centered()
	close_button.grab_focus()
	return loaded_count > 0


# ── Web: fetch photos on demand ─────────────────────────────────────────────

## Starts (or reuses cached) downloads for this exercise's photos and returns
## how many images it will show. Textures are applied as each download lands.
func _show_web_images(images: Array, image_controls: Array[TextureRect]) -> int:
	_web_request_serial += 1
	var serial := _web_request_serial
	var count := mini(images.size(), image_controls.size())
	var pending := 0
	_web_pending = 0
	for index in range(count):
		var source_path := String((images[index] as Dictionary).get("source_path", ""))
		if source_path.is_empty():
			continue
		if _web_texture_cache.has(source_path):
			image_controls[index].texture = _web_texture_cache[source_path]
		else:
			pending += 1
			_web_pending += 1
			_fetch_web_image(source_path, image_controls[index], serial)
	message_label.visible = pending > 0 or count == 0
	if count == 0:
		message_label.text = "No demonstration images are available."
	elif pending > 0:
		message_label.text = "Loading images…"
	return count


func _fetch_web_image(source_path: String, target: TextureRect, serial: int) -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			request.queue_free()
			var texture: Texture2D = null
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var image := Image.new()
				if image.load_jpg_from_buffer(body) == OK:
					texture = ImageTexture.create_from_image(image)
					_web_texture_cache[source_path] = texture
			if serial != _web_request_serial:
				return   # the popup moved on to another exercise
			_web_pending -= 1
			if texture != null:
				target.texture = texture
				if _web_pending == 0 and message_label.text == "Loading images…":
					message_label.visible = false
			else:
				message_label.visible = true
				message_label.text = "Couldn't load the demonstration images."
	)
	var error := request.request(_web_photo_url(source_path))
	if error != OK:
		request.queue_free()
		_web_pending -= 1
		message_label.visible = true
		message_label.text = "Couldn't load the demonstration images."


## Absolute URL for a photo, resolved against the page so the build works at
## any path (localhost, GitHub Pages project sites, etc.).
func _web_photo_url(source_path: String) -> String:
	var encoded := PackedStringArray()
	for part in source_path.split("/"):
		encoded.append(part.uri_encode())
	var relative := WEB_PHOTO_DIR + "/".join(encoded)
	var base = JavaScriptBridge.eval("document.baseURI", true)
	if base is String and not String(base).is_empty():
		return String(JavaScriptBridge.eval("new URL(%s, document.baseURI).href" % JSON.stringify(relative), true))
	return relative

extends CanvasLayer

@onready var camera: Camera2D = $BoardRoot/Camera2D
@onready var board_view: Node2D = $BoardRoot/BoardView
@onready var deployment_zones: Node2D = $BoardRoot/DeploymentZones
@onready var p1_zone: Polygon2D = $BoardRoot/DeploymentZones/P1Zone
@onready var p2_zone: Polygon2D = $BoardRoot/DeploymentZones/P2Zone
@onready var token_layer: Node2D = $BoardRoot/TokenLayer
@onready var ghost_layer: Node2D = $BoardRoot/GhostLayer

@onready var phase_label: Label = $HUD_Bottom/HBoxContainer/PhaseLabel
@onready var active_player_badge: Label = $HUD_Bottom/HBoxContainer/ActivePlayerBadge
@onready var status_label: Label = $HUD_Bottom/HBoxContainer/StatusLabel
@onready var end_deployment_button: Button = $HUD_Bottom/HBoxContainer/EndDeploymentButton

@onready var unit_list: ItemList = $HUD_Right/VBoxContainer/UnitListPanel
@onready var unit_card: VBoxContainer = $HUD_Right/VBoxContainer/UnitCard
@onready var unit_name_label: Label = $HUD_Right/VBoxContainer/UnitCard/UnitNameLabel
@onready var keywords_label: Label = $HUD_Right/VBoxContainer/UnitCard/KeywordsLabel
@onready var models_label: Label = $HUD_Right/VBoxContainer/UnitCard/ModelsLabel
@onready var undo_button: Button = $HUD_Right/VBoxContainer/UnitCard/ButtonContainer/UndoButton
@onready var confirm_button: Button = $HUD_Right/VBoxContainer/UnitCard/ButtonContainer/ConfirmButton

var deployment_controller: Node
var view_offset: Vector2 = Vector2.ZERO
var view_zoom: float = 1.0

func _ready() -> void:
	# Initialize view to show whole board
	view_zoom = 0.3
	view_offset = Vector2(0, 0)  # Start at top-left
	update_view_transform()
	
	# Camera controls: WASD/arrows to pan, +/- to zoom, F to focus on Player 2 zone
	
	board_view.queue_redraw()
	setup_deployment_zones()
	setup_deployment_controller()
	connect_signals()
	refresh_unit_list()
	update_ui()

func setup_deployment_zones() -> void:
	var zone1 = BoardState.get_deployment_zone_for_player(1)
	var zone2 = BoardState.get_deployment_zone_for_player(2)
	
	p1_zone.polygon = zone1
	p2_zone.polygon = zone2
	
	update_deployment_zone_visibility()

func setup_deployment_controller() -> void:
	deployment_controller = preload("res://scripts/DeploymentController.gd").new()
	deployment_controller.name = "DeploymentController"
	add_child(deployment_controller)
	deployment_controller.set_layers(token_layer, ghost_layer)

func connect_signals() -> void:
	unit_list.item_selected.connect(_on_unit_selected)
	undo_button.pressed.connect(_on_undo_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	end_deployment_button.pressed.connect(_on_end_deployment_pressed)
	
	TurnManager.deployment_side_changed.connect(_on_deployment_side_changed)
	TurnManager.deployment_phase_complete.connect(_on_deployment_complete)
	
	deployment_controller.unit_confirmed.connect(_on_unit_confirmed)
	deployment_controller.models_placed_changed.connect(_on_models_placed_changed)
	

func _input(event: InputEvent) -> void:
	# Handle mouse clicks for placement - but only consume if we actually place something
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if deployment_controller.is_placing():
			# Check if click is on the board area (not on UI)
			var ui_rect = get_viewport().get_visible_rect()
			var right_hud_rect = Rect2(ui_rect.size.x - 400, 0, 400, ui_rect.size.y)  # Right HUD area
			var bottom_hud_rect = Rect2(0, ui_rect.size.y - 100, ui_rect.size.x, 100)  # Bottom HUD area
			
			if not right_hud_rect.has_point(event.position) and not bottom_hud_rect.has_point(event.position):
				var world_pos = screen_to_world_position(event.position)
				deployment_controller.try_place_at(world_pos)
				get_viewport().set_input_as_handled()

func screen_to_world_position(screen_pos: Vector2) -> Vector2:
	# Convert screen position to world position using our transform
	var board_transform = $BoardRoot.transform
	return board_transform.affine_inverse() * screen_pos

func _process(delta: float) -> void:
	# View controls using BoardRoot transform
	var pan_speed = 800.0 * delta / view_zoom
	var view_changed = false
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		view_offset.y -= pan_speed
		view_changed = true
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		view_offset.y += pan_speed
		view_changed = true
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		view_offset.x -= pan_speed
		view_changed = true
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		view_offset.x += pan_speed
		view_changed = true
	
	# Zoom controls
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS):
		view_zoom *= 1.03
		view_zoom = clamp(view_zoom, 0.1, 3.0)
		view_changed = true
	if Input.is_key_pressed(KEY_MINUS):
		view_zoom *= 0.97
		view_zoom = clamp(view_zoom, 0.1, 3.0)
		view_changed = true
	
	# Focus commands
	if Input.is_key_pressed(KEY_F):
		focus_on_player2_zone()
		view_changed = true
	
	
	if view_changed:
		update_view_transform()

func reset_camera() -> void:
	camera.position = Vector2(
		SettingsService.get_board_width_px() / 2,
		SettingsService.get_board_height_px() / 2
	)
	camera.zoom = Vector2(0.3, 0.3)
	print("Camera reset to position: ", camera.position, " zoom: ", camera.zoom)

func update_view_transform() -> void:
	# Apply transform to BoardRoot to simulate camera movement
	var transform = Transform2D()
	transform = transform.scaled(Vector2(view_zoom, view_zoom))
	transform.origin = -view_offset * view_zoom
	$BoardRoot.transform = transform

func focus_on_player2_zone() -> void:
	var zone2 = BoardState.get_deployment_zone_for_player(2)
	if zone2.size() > 0:
		# Calculate center of the zone
		var center = Vector2.ZERO
		for point in zone2:
			center += point
		center /= zone2.size()
		
		view_offset = center - get_viewport().get_visible_rect().size / 2
		view_zoom = 0.8
		print("Focused view on Player 2 zone at: ", center)

func refresh_unit_list() -> void:
	unit_list.clear()
	var units = BoardState.get_undeployed_units_for_player(BoardState.active_player)
	
	for unit_id in units:
		var unit_data = BoardState.units[unit_id]
		var unit_name = unit_data["meta"]["name"]
		var model_count = unit_data["models"].size()
		var display_text = "%s (%d models)" % [unit_name, model_count]
		unit_list.add_item(display_text)
		unit_list.set_item_metadata(unit_list.get_item_count() - 1, unit_id)

func update_ui() -> void:
	var player_text = "Player %d (%s)" % [
		BoardState.active_player,
		"Defender" if BoardState.active_player == 1 else "Attacker"
	]
	active_player_badge.text = player_text
	
	if BoardState.all_units_deployed():
		end_deployment_button.disabled = false
		status_label.text = "All units deployed! Click 'End Deployment' to continue."
	else:
		end_deployment_button.disabled = true
		if deployment_controller.is_placing():
			var unit_id = deployment_controller.get_current_unit()
			var unit_name = BoardState.units[unit_id]["meta"]["name"]
			var placed = deployment_controller.get_placed_count()
			var total = BoardState.get_model_count(unit_id)
			status_label.text = "Placing: %s — %d/%d models" % [unit_name, placed, total]
		else:
			status_label.text = "Select a unit to deploy"

func _on_unit_selected(index: int) -> void:
	if deployment_controller.is_placing():
		return
	
	var unit_id = unit_list.get_item_metadata(index)
	deployment_controller.begin_deploy(unit_id)
	
	show_unit_card(unit_id)
	unit_list.visible = false
	update_ui()

func show_unit_card(unit_id: String) -> void:
	var unit_data = BoardState.units[unit_id]
	unit_name_label.text = unit_data["meta"]["name"]
	keywords_label.text = "Keywords: " + ", ".join(unit_data["meta"]["keywords"])
	
	unit_card.visible = true
	update_unit_card_buttons()

func update_unit_card_buttons() -> void:
	var placed = deployment_controller.get_placed_count()
	var total = BoardState.get_model_count(deployment_controller.get_current_unit())
	
	models_label.text = "Models: %d/%d" % [placed, total]
	
	# Show buttons based on deployment progress
	undo_button.visible = placed > 0
	confirm_button.visible = placed == total

func _on_undo_pressed() -> void:
	deployment_controller.undo()
	unit_card.visible = false
	unit_list.visible = true
	update_ui()

func _on_confirm_pressed() -> void:
	deployment_controller.confirm()

func _on_unit_confirmed() -> void:
	unit_card.visible = false
	unit_list.visible = true
	refresh_unit_list()
	update_ui()

func _on_models_placed_changed() -> void:
	update_unit_card_buttons()
	update_ui()

func _on_deployment_side_changed(player: int) -> void:
	refresh_unit_list()
	update_ui()
	update_deployment_zone_visibility()

func _on_deployment_complete() -> void:
	status_label.text = "Deployment complete!"
	end_deployment_button.disabled = false

func _on_end_deployment_pressed() -> void:
	print("Moving to next phase...")

func update_deployment_zone_visibility() -> void:
	# Show the active player's zone more prominently
	if BoardState.active_player == 1:
		p1_zone.modulate = Color(0, 0, 1, 0.6)  # Brighter blue for active
		p2_zone.modulate = Color(1, 0, 0, 0.3)  # Visible red for inactive
		p1_zone.visible = true
		p2_zone.visible = true
		# Set active borders
		if p1_zone.has_method("set_active"):
			p1_zone.set_active(true)
			p1_zone.border_color = Color(0, 0.3, 1, 1)
		if p2_zone.has_method("set_active"):
			p2_zone.set_active(false)
	else:
		p1_zone.modulate = Color(0, 0, 1, 0.3)  # Visible blue for inactive
		p2_zone.modulate = Color(1, 0, 0, 0.6)  # Brighter red for active
		p1_zone.visible = true
		p2_zone.visible = true
		# Set active borders
		if p1_zone.has_method("set_active"):
			p1_zone.set_active(false)
		if p2_zone.has_method("set_active"):
			p2_zone.set_active(true)
			p2_zone.border_color = Color(1, 0.3, 0, 1)
extends BasePhase
class_name MovementPhase

# MovementPhase - Stub implementation for the Movement phase
# This is a placeholder that can be expanded with full movement logic

func _init():
	phase_type = GameStateData.Phase.MOVEMENT

func _on_phase_enter() -> void:
	log_phase_message("Entering Movement Phase")
	
	# Initialize movement phase state
	_initialize_movement()

func _on_phase_exit() -> void:
	log_phase_message("Exiting Movement Phase")

func _initialize_movement() -> void:
	# Check if there are any units that can move
	var current_player = get_current_player()
	var units = get_units_for_player(current_player)
	
	var can_move = false
	for unit_id in units:
		var unit = units[unit_id]
		if unit.get("status", 0) == GameStateData.UnitStatus.DEPLOYED:
			can_move = true
			break
	
	if not can_move:
		log_phase_message("No units available for movement, completing phase")
		emit_signal("phase_completed")

func validate_action(action: Dictionary) -> Dictionary:
	var action_type = action.get("type", "")
	
	match action_type:
		"MOVE_UNIT":
			return _validate_move_unit_action(action)
		"ADVANCE_UNIT":
			return _validate_advance_unit_action(action)
		"FALL_BACK":
			return _validate_fall_back_action(action)
		"SKIP_MOVEMENT":
			return _validate_skip_movement_action(action)
		_:
			return {"valid": false, "errors": ["Unknown action type: " + action_type]}

func _validate_move_unit_action(action: Dictionary) -> Dictionary:
	var errors = []
	
	# Check required fields
	var required_fields = ["unit_id", "new_positions"]
	for field in required_fields:
		if not action.has(field):
			errors.append("Missing required field: " + field)
	
	if errors.size() > 0:
		return {"valid": false, "errors": errors}
	
	var unit_id = action.unit_id
	var unit = get_unit(unit_id)
	
	# Check if unit exists and belongs to active player
	if unit.is_empty():
		errors.append("Unit not found: " + unit_id)
	elif unit.get("owner", 0) != get_current_player():
		errors.append("Unit does not belong to active player")
	elif unit.get("status", 0) != GameStateData.UnitStatus.DEPLOYED:
		errors.append("Unit is not available for movement")
	
	# TODO: Add detailed movement validation
	# - Check movement distance
	# - Check terrain effects
	# - Check enemy unit blocking
	# - Check coherency after movement
	
	return {"valid": errors.size() == 0, "errors": errors}

func _validate_advance_unit_action(action: Dictionary) -> Dictionary:
	# Advance allows double movement but no shooting
	var base_validation = _validate_move_unit_action(action)
	if not base_validation.valid:
		return base_validation
	
	# TODO: Add advance-specific validation
	# - Check if unit is within 1" of enemy (cannot advance)
	# - Mark unit as advanced (affects shooting phase)
	
	return {"valid": true, "errors": []}

func _validate_fall_back_action(action: Dictionary) -> Dictionary:
	var base_validation = _validate_move_unit_action(action)
	if not base_validation.valid:
		return base_validation
	
	# TODO: Add fall back specific validation
	# - Check if unit is in combat
	# - Check if unit can disengage
	# - Mark unit as fallen back (affects shooting and charging)
	
	return {"valid": true, "errors": []}

func _validate_skip_movement_action(action: Dictionary) -> Dictionary:
	var unit_id = action.get("unit_id", "")
	if unit_id == "":
		return {"valid": false, "errors": ["Missing unit_id"]}
	
	var unit = get_unit(unit_id)
	if unit.is_empty():
		return {"valid": false, "errors": ["Unit not found"]}
	
	return {"valid": true, "errors": []}

func process_action(action: Dictionary) -> Dictionary:
	var action_type = action.get("type", "")
	
	match action_type:
		"MOVE_UNIT":
			return _process_move_unit(action)
		"ADVANCE_UNIT":
			return _process_advance_unit(action)
		"FALL_BACK":
			return _process_fall_back(action)
		"SKIP_MOVEMENT":
			return _process_skip_movement(action)
		_:
			return create_result(false, [], "Unknown action type: " + action_type)

func _process_move_unit(action: Dictionary) -> Dictionary:
	var unit_id = action.unit_id
	var new_positions = action.new_positions
	var changes = []
	
	# Update model positions
	for i in range(new_positions.size()):
		var pos = new_positions[i]
		if pos != null:
			changes.append({
				"op": "set",
				"path": "units.%s.models.%d.position" % [unit_id, i],
				"value": {"x": pos.x, "y": pos.y}
			})
	
	# Mark unit as moved
	changes.append({
		"op": "set",
		"path": "units.%s.status" % unit_id,
		"value": GameStateData.UnitStatus.MOVED
	})
	
	# Apply changes through PhaseManager
	if get_parent() and get_parent().has_method("apply_state_changes"):
		get_parent().apply_state_changes(changes)
	
	var unit = get_unit(unit_id)
	var unit_name = unit.get("meta", {}).get("name", unit_id)
	log_phase_message("Moved %s" % unit_name)
	
	return create_result(true, changes)

func _process_advance_unit(action: Dictionary) -> Dictionary:
	# Process as normal move but mark as advanced
	var result = _process_move_unit(action)
	if result.success:
		var unit_id = action.unit_id
		var advance_change = {
			"op": "set",
			"path": "units.%s.advanced" % unit_id,
			"value": true
		}
		
		if get_parent() and get_parent().has_method("apply_state_changes"):
			get_parent().apply_state_changes([advance_change])
		
		result.changes.append(advance_change)
		log_phase_message("Advanced unit %s" % unit_id)
	
	return result

func _process_fall_back(action: Dictionary) -> Dictionary:
	# Process as normal move but mark as fallen back
	var result = _process_move_unit(action)
	if result.success:
		var unit_id = action.unit_id
		var fall_back_change = {
			"op": "set",
			"path": "units.%s.fallen_back" % unit_id,
			"value": true
		}
		
		if get_parent() and get_parent().has_method("apply_state_changes"):
			get_parent().apply_state_changes([fall_back_change])
		
		result.changes.append(fall_back_change)
		log_phase_message("Unit %s fell back" % unit_id)
	
	return result

func _process_skip_movement(action: Dictionary) -> Dictionary:
	var unit_id = action.unit_id
	log_phase_message("Skipped movement for %s" % unit_id)
	return create_result(true, [])

func get_available_actions() -> Array:
	var actions = []
	var current_player = get_current_player()
	var units = get_units_for_player(current_player)
	
	for unit_id in units:
		var unit = units[unit_id]
		if unit.get("status", 0) == GameStateData.UnitStatus.DEPLOYED:
			# Basic movement
			actions.append({
				"type": "MOVE_UNIT",
				"unit_id": unit_id,
				"description": "Move " + unit.get("meta", {}).get("name", unit_id)
			})
			
			# Advance (double move, no shooting)
			actions.append({
				"type": "ADVANCE_UNIT", 
				"unit_id": unit_id,
				"description": "Advance " + unit.get("meta", {}).get("name", unit_id)
			})
			
			# Skip movement
			actions.append({
				"type": "SKIP_MOVEMENT",
				"unit_id": unit_id,
				"description": "Skip movement for " + unit.get("meta", {}).get("name", unit_id)
			})
			
			# TODO: Add conditional actions
			# - Fall back (only if in combat)
			# - Remain stationary (for heavy weapons bonus)
	
	return actions

func _should_complete_phase() -> bool:
	# For now, require manual phase completion
	# TODO: Implement automatic completion logic
	# - All units have moved or been marked to skip
	# - No more legal moves available
	return false

# TODO: Add helper methods for movement calculation
# func _calculate_movement_distance(from_pos: Vector2, to_pos: Vector2) -> float
# func _check_terrain_effects(unit: Dictionary, path: Array) -> Dictionary
# func _validate_coherency_after_move(unit: Dictionary, new_positions: Array) -> bool
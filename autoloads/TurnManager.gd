extends Node

signal deployment_side_changed(player: int)
signal deployment_phase_complete()

func _ready() -> void:
	if GameManager:
		GameManager.result_applied.connect(_on_result_applied)
	start_deployment_phase()

func _on_result_applied(result: Dictionary) -> void:
	if result["phase"] != "DEPLOYMENT":
		return
	
	check_deployment_alternation()

func check_deployment_alternation() -> void:
	var player1_has_units = BoardState.has_undeployed_units(1)
	var player2_has_units = BoardState.has_undeployed_units(2)
	
	if not player1_has_units and not player2_has_units:
		emit_signal("deployment_phase_complete")
		return
	
	if player1_has_units and player2_has_units:
		alternate_active_player()
	elif player1_has_units:
		BoardState.active_player = 1
		emit_signal("deployment_side_changed", 1)
	elif player2_has_units:
		BoardState.active_player = 2
		emit_signal("deployment_side_changed", 2)

func alternate_active_player() -> void:
	BoardState.active_player = 2 if BoardState.active_player == 1 else 1
	emit_signal("deployment_side_changed", BoardState.active_player)

func start_deployment_phase() -> void:
	BoardState.phase = BoardState.Phase.DEPLOYMENT
	BoardState.active_player = 1
	emit_signal("deployment_side_changed", 1)
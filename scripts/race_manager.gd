class_name RaceManager
extends Node3D

const CHECKPOINT_WIDTH = 82.0
const CHECKPOINT_HEIGHT = 10.0
const CHECKPOINT_DEPTH = 18.0
const FALL_RESPAWN_Y = -18.0
const COUNTDOWN_DURATION = 3.15
const START_BOOST_EARLY_BURNOUT_TIME = 1.10
const START_BOOST_WINDOW_START = 1.55
const START_BOOST_WINDOW_END = 2.82
const START_BOOST_DURATION = 1.25
const START_BOOST_BONUS = 20.0
const START_BURNOUT_DURATION = 1.15
const ITEM_NONE = ""
const ITEM_MUSHROOM = "MUSHROOM"
const ITEM_ROULETTE_DURATION = 1.15
const MUSHROOM_BOOST_DURATION = 0.95
const MUSHROOM_BOOST_BONUS = 16.0
const LIGHT_KART_STATS: KartStats = preload("res://resources/karts/light_kart_stats.tres")
const STANDARD_BIKE_STATS: KartStats = preload("res://resources/karts/standard_bike_stats.tres")
const INSIDE_DRIFT_BIKE_STATS: KartStats = preload("res://resources/karts/inside_drift_bike_stats.tres")
const OUTSIDE_DRIFT_BIKE_STATS: KartStats = preload("res://resources/karts/outside_drift_bike_stats.tres")
const HEAVY_KART_STATS: KartStats = preload("res://resources/karts/heavy_kart_stats.tres")

@export var total_laps: int = 3
@export var show_checkpoint_gates: bool = true
@export var checkpoint_visual_mode: RaceCheckpoint3D.VisualMode = RaceCheckpoint3D.VisualMode.GROUND_LINE_ONLY
@export var selected_vehicle_index: int = 1
@export var player_path: NodePath = NodePath("../MotorcycleKart")

var _vehicle_presets: Array[KartStats] = [
    LIGHT_KART_STATS,
    STANDARD_BIKE_STATS,
    INSIDE_DRIFT_BIKE_STATS,
    OUTSIDE_DRIFT_BIKE_STATS,
    HEAVY_KART_STATS
]

var _route_points: Array[Vector3] = [
    Vector3(-179.0, 3.05, 188.7),
    Vector3(-102.0, 3.05, 229.0),
    Vector3(18.0, 3.05, 193.0),
    Vector3(163.0, 3.05, 222.0),
    Vector3(241.0, 3.05, 191.0),
    Vector3(246.0, 3.05, 105.0),
    Vector3(234.0, 3.05, -31.0),
    Vector3(168.0, 3.05, -228.0),
    Vector3(-33.0, 3.05, -197.0),
    Vector3(-186.0, 3.05, -233.0),
    Vector3(-250.0, 3.05, -186.0),
    Vector3(-239.0, 3.05, -95.0),
    Vector3(-249.0, 3.05, 32.0),
    Vector3(-218.0, 3.05, 162.0)
]

var _checkpoints: Array[RaceCheckpoint3D] = []
var _player: MotorcycleBicycleControllerV4 = null
var _current_lap: int = 1
var _next_checkpoint_index: int = 1
var _last_checkpoint_index: int = 0
var _race_time: float = 0.0
var _race_started: bool = false
var _race_finished: bool = false
var _countdown_active: bool = false
var _countdown_time: float = 0.0
var _countdown_start_msec: int = 0
var _last_accelerate_pressed: bool = false
var _accelerate_first_press_time: float = -1.0
var _start_boost_eligible: bool = false
var _start_burnout_pending: bool = false
var _held_item: String = ITEM_NONE
var _roulette_timer: float = 0.0
var _roulette_step_timer: float = 0.0
var _roulette_display_index: int = 0
var _wrong_way_message_timer: float = 0.0
var _countdown_label_hide_timer: float = 0.0
var _last_respawn_transform: Transform3D = Transform3D.IDENTITY

var _canvas: CanvasLayer = null
var _lap_label: Label = null
var _time_label: Label = null
var _checkpoint_label: Label = null
var _message_label: Label = null
var _item_label: Label = null
var _vehicle_label: Label = null
var _vehicle_detail_label: Label = null
var _countdown_label: Label = null


func _ready() -> void:
    _ensure_item_input_action()
    _player = get_node_or_null(player_path) as MotorcycleBicycleControllerV4
    if _player == null:
        _player = get_tree().current_scene.get_node_or_null("MotorcycleKart") as MotorcycleBicycleControllerV4
    _apply_selected_vehicle_preset()
    _create_checkpoints()
    _create_hud()
    _connect_item_boxes()
    call_deferred("_connect_item_boxes")
    _initialize_race_state()


func _input(event: InputEvent) -> void:
    var key_event: InputEventKey = event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo:
        return
    var keycode: Key = key_event.physical_keycode
    if keycode == KEY_NONE:
        keycode = key_event.keycode
    match keycode:
        KEY_1:
            select_vehicle_preset(0)
        KEY_2:
            select_vehicle_preset(1)
        KEY_3:
            select_vehicle_preset(2)
        KEY_4:
            select_vehicle_preset(3)
        KEY_5:
            select_vehicle_preset(4)
        KEY_TAB:
            select_vehicle_preset((selected_vehicle_index + 1) % _vehicle_presets.size())


func _process(delta: float) -> void:
    if _countdown_active:
        _update_countdown(delta)
    if _race_started and not _race_finished:
        _race_time += delta
        _update_item_roulette(delta)
        _handle_item_use_input()
    if _wrong_way_message_timer > 0.0:
        _wrong_way_message_timer = maxf(_wrong_way_message_timer - delta, 0.0)
        if _wrong_way_message_timer <= 0.0:
            _set_message("")
    if _countdown_label_hide_timer > 0.0:
        _countdown_label_hide_timer = maxf(_countdown_label_hide_timer - delta, 0.0)
        if _countdown_label_hide_timer <= 0.0 and not _countdown_active:
            _update_countdown_label("")
    if _player != null and _player.global_position.y < FALL_RESPAWN_Y:
        respawn_player()
    if Input.is_key_pressed(KEY_R):
        respawn_player()
    _update_hud()


func _ensure_item_input_action() -> void:
    if not InputMap.has_action("use_item"):
        InputMap.add_action("use_item")
        var event: InputEventKey = InputEventKey.new()
        event.physical_keycode = KEY_E
        InputMap.action_add_event("use_item", event)


func select_vehicle_preset(index: int) -> void:
    if _vehicle_presets.is_empty():
        return
    selected_vehicle_index = clampi(index, 0, _vehicle_presets.size() - 1)
    _apply_selected_vehicle_preset()
    _update_vehicle_label()


func _apply_selected_vehicle_preset() -> void:
    if _player == null or _vehicle_presets.is_empty():
        return
    selected_vehicle_index = clampi(selected_vehicle_index, 0, _vehicle_presets.size() - 1)
    var selected_stats: KartStats = _vehicle_presets[selected_vehicle_index]
    _player.set_kart_stats(selected_stats)
    _set_message("Vehicle: %s" % selected_stats.display_name, 1.2)


func _connect_item_boxes() -> void:
    for node: Node in get_tree().get_nodes_in_group("item_boxes"):
        var item_box: ItemBox3D = node as ItemBox3D
        if item_box != null and not item_box.item_box_collected.is_connected(Callable(self, "_on_item_box_collected")):
            item_box.item_box_collected.connect(Callable(self, "_on_item_box_collected"))


func _create_checkpoints() -> void:
    for child: Node in get_children():
        if child is RaceCheckpoint3D:
            child.queue_free()
    _checkpoints.clear()
    for index: int in range(_route_points.size()):
        var checkpoint: RaceCheckpoint3D = RaceCheckpoint3D.new()
        checkpoint.name = "CP%02d_%s" % [index, "StartFinish" if index == 0 else "Route"]
        checkpoint.checkpoint_height = CHECKPOINT_HEIGHT
        checkpoint.checkpoint_depth = CHECKPOINT_DEPTH
        checkpoint.show_gate_visual = show_checkpoint_gates
        checkpoint.visual_mode = checkpoint_visual_mode
        add_child(checkpoint)
        var previous_point: Vector3 = _route_points[(index - 1 + _route_points.size()) % _route_points.size()]
        var next_point: Vector3 = _route_points[(index + 1) % _route_points.size()]
        var forward: Vector3 = next_point - previous_point
        var width: float = CHECKPOINT_WIDTH + (18.0 if index == 0 else 0.0)
        checkpoint.setup(index, _route_points[index], forward, width, index == 0)
        checkpoint.kart_entered.connect(Callable(self, "_on_checkpoint_entered"))
        _checkpoints.append(checkpoint)


func _initialize_race_state() -> void:
    _current_lap = 1
    _next_checkpoint_index = 1
    _last_checkpoint_index = 0
    _race_time = 0.0
    _race_started = false
    _race_finished = false
    _countdown_active = true
    _countdown_time = 0.0
    _countdown_start_msec = Time.get_ticks_msec()
    _accelerate_first_press_time = -1.0
    _start_boost_eligible = false
    _start_burnout_pending = false
    _held_item = ITEM_NONE
    _roulette_timer = 0.0
    _roulette_step_timer = 0.0
    _roulette_display_index = 0
    _last_accelerate_pressed = _is_player_accelerating()
    if _player != null:
        _player.set_controls_locked(true)
    if not _checkpoints.is_empty():
        _last_respawn_transform = _checkpoints[0].respawn_transform
    _set_message("Time your throttle for a start boost", 0.0)
    _update_countdown_label("3")
    _update_hud()


func _on_checkpoint_entered(checkpoint: RaceCheckpoint3D, kart: Node3D) -> void:
    if _countdown_active or not _race_started or _race_finished or kart != _player:
        return
    var index: int = checkpoint.checkpoint_index
    if index == _next_checkpoint_index:
        _accept_checkpoint(index)
    elif index == _last_checkpoint_index:
        return
    else:
        _set_message("Wrong checkpoint: find CP %d" % _next_checkpoint_index, 1.5)


func _accept_checkpoint(index: int) -> void:
    _last_checkpoint_index = index
    _last_respawn_transform = _checkpoints[index].respawn_transform
    if index == 0:
        _current_lap += 1
        if _current_lap > total_laps:
            _finish_race()
            return
        _set_message("Lap %d/%d" % [_current_lap, total_laps], 1.8)
        _next_checkpoint_index = 1
    else:
        _next_checkpoint_index = (index + 1) % _checkpoints.size()
        _set_message("Checkpoint %d/%d" % [index, _checkpoints.size() - 1], 0.75)


func _finish_race() -> void:
    _race_finished = true
    _race_started = false
    _set_message("FINISH! %s" % _format_time(_race_time), 10.0)


func _update_countdown(_delta: float) -> void:
    _countdown_time = float(Time.get_ticks_msec() - _countdown_start_msec) / 1000.0
    _track_countdown_accelerator_input()
    if _countdown_time < 1.0:
        _update_countdown_label("3")
    elif _countdown_time < 2.0:
        _update_countdown_label("2")
    elif _countdown_time < 3.0:
        _update_countdown_label("1")
    else:
        _start_race_from_countdown()


func _track_countdown_accelerator_input() -> void:
    var accelerating: bool = _is_player_accelerating()
    if accelerating and not _last_accelerate_pressed:
        _accelerate_first_press_time = _countdown_time
        if _countdown_time < START_BOOST_EARLY_BURNOUT_TIME:
            _start_burnout_pending = true
            _start_boost_eligible = false
            _set_message("Too early! Burnout!", 0.0)
        elif _countdown_time >= START_BOOST_WINDOW_START and _countdown_time <= START_BOOST_WINDOW_END:
            _start_boost_eligible = true
            _set_message("Good timing - hold it!", 0.0)
        else:
            _start_boost_eligible = false
            _set_message("", 0.0)
    if not accelerating and _last_accelerate_pressed and _countdown_time < COUNTDOWN_DURATION:
        _start_boost_eligible = false
    _last_accelerate_pressed = accelerating


func _start_race_from_countdown() -> void:
    _countdown_active = false
    _race_started = true
    _race_time = 0.0
    if _player != null:
        _player.set_controls_locked(false)
    var accelerating: bool = _is_player_accelerating()
    if _start_burnout_pending:
        if _player != null:
            _player.apply_burnout(START_BURNOUT_DURATION)
        _update_countdown_label("BURNOUT", 1.4)
        _set_message("Burnout! Wait for the revs to recover.", 2.0)
    elif _start_boost_eligible and accelerating:
        if _player != null:
            _player.apply_start_boost(START_BOOST_DURATION, START_BOOST_BONUS)
        _update_countdown_label("BOOST!", 1.2)
        _set_message("Start boost!", 1.5)
    else:
        _update_countdown_label("GO!", 1.0)
        _set_message("GO!", 1.2)


func _is_player_accelerating() -> bool:
    if _player == null:
        return Input.is_action_pressed("drive_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
    return _player.is_accelerating_input_pressed()


func _on_item_box_collected(item_box: ItemBox3D, kart: Node3D) -> void:
    if kart != _player or _countdown_active or _race_finished:
        item_box.set_available(true)
        return
    if _held_item != ITEM_NONE or _roulette_timer > 0.0:
        item_box.set_available(true)
        return
    _roulette_timer = ITEM_ROULETTE_DURATION
    _roulette_step_timer = 0.0
    _roulette_display_index = 0
    _set_message("Item roulette...", 0.9)
    _update_item_label()


func _update_item_roulette(delta: float) -> void:
    if _roulette_timer <= 0.0:
        return
    _roulette_timer = maxf(_roulette_timer - delta, 0.0)
    _roulette_step_timer += delta
    if _roulette_step_timer >= 0.12:
        _roulette_step_timer = 0.0
        _roulette_display_index = (_roulette_display_index + 1) % 4
    if _roulette_timer <= 0.0:
        _held_item = ITEM_MUSHROOM
        _set_message("Got Mushroom! Press E to use.", 2.0)
    _update_item_label()


func _handle_item_use_input() -> void:
    if _held_item == ITEM_NONE or _roulette_timer > 0.0:
        return
    if Input.is_action_just_pressed("use_item") or Input.is_physical_key_pressed(KEY_E):
        _use_held_item()


func _use_held_item() -> void:
    if _held_item == ITEM_MUSHROOM:
        if _player != null:
            _player.apply_mushroom_boost(MUSHROOM_BOOST_DURATION, MUSHROOM_BOOST_BONUS)
        _held_item = ITEM_NONE
        _set_message("Mushroom boost!", 1.2)
        _update_item_label()


func respawn_player() -> void:
    if _player == null:
        return
    _player.respawn_to_transform(_last_respawn_transform)
    _set_message("Respawned at CP %d" % _last_checkpoint_index, 1.5)


func _create_hud() -> void:
    _canvas = CanvasLayer.new()
    _canvas.name = "RaceHUD"
    _canvas.layer = 50
    add_child(_canvas)
    var panel: PanelContainer = PanelContainer.new()
    panel.name = "RacePanel"
    panel.position = Vector2(16.0, 250.0)
    panel.custom_minimum_size = Vector2(430.0, 206.0)
    _canvas.add_child(panel)
    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)
    _countdown_label = Label.new()
    _countdown_label.name = "CountdownLabel"
    _countdown_label.text = ""
    _countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _countdown_label.add_theme_font_size_override("font_size", 96)
    _canvas.add_child(_countdown_label)
    _countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _countdown_label.offset_left = 0.0
    _countdown_label.offset_top = -80.0
    _countdown_label.offset_right = 0.0
    _countdown_label.offset_bottom = -80.0
    var box: VBoxContainer = VBoxContainer.new()
    margin.add_child(box)
    _lap_label = _make_hud_label("Lap 1/%d" % total_laps, 22)
    _time_label = _make_hud_label("Time 0:00.000", 18)
    _checkpoint_label = _make_hud_label("Next CP 1", 16)
    _vehicle_label = _make_hud_label("Vehicle: Standard Bike", 16)
    _vehicle_detail_label = _make_hud_label("1-5/Tab switch presets", 13)
    _item_label = _make_hud_label("Item: Empty  |  E = use", 18)
    _message_label = _make_hud_label("", 18)
    box.add_child(_lap_label)
    box.add_child(_time_label)
    box.add_child(_checkpoint_label)
    box.add_child(_vehicle_label)
    box.add_child(_vehicle_detail_label)
    box.add_child(_item_label)
    box.add_child(_message_label)


func _make_hud_label(text_value: String, font_size: int) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    return label


func _update_hud() -> void:
    if _lap_label != null:
        _lap_label.text = "Lap %d/%d" % [mini(_current_lap, total_laps), total_laps]
    if _time_label != null:
        _time_label.text = "Time %s" % _format_time(_race_time)
    if _checkpoint_label != null:
        _checkpoint_label.text = "Next CP %d  |  R = respawn" % _next_checkpoint_index
    _update_vehicle_label()
    _update_item_label()


func _update_vehicle_label() -> void:
    if _vehicle_presets.is_empty():
        return
    selected_vehicle_index = clampi(selected_vehicle_index, 0, _vehicle_presets.size() - 1)
    var selected_stats: KartStats = _vehicle_presets[selected_vehicle_index]
    if _vehicle_label != null:
        _vehicle_label.text = "Vehicle %d/%d: %s" % [selected_vehicle_index + 1, _vehicle_presets.size(), selected_stats.display_name]
    if _vehicle_detail_label != null:
        _vehicle_detail_label.text = "%s %s | speed %.1f accel %.1f MT %.2fs | 1-5/Tab" % [selected_stats.weight_class, selected_stats.vehicle_type, selected_stats.max_forward_speed, selected_stats.engine_acceleration, selected_stats.mini_turbo_charge_duration]


func _update_item_label() -> void:
    if _item_label == null:
        return
    if _roulette_timer > 0.0:
        var roulette_names: Array[String] = ["?", "MUSH", "STAR", "SHELL"]
        _item_label.text = "Item: [%s] rolling..." % roulette_names[_roulette_display_index]
    elif _held_item == ITEM_MUSHROOM:
        _item_label.text = "Item: Mushroom  |  E = use"
    else:
        _item_label.text = "Item: Empty  |  E = use"


func _update_countdown_label(text_value: String, hide_after: float = 0.0) -> void:
    if _countdown_label != null:
        _countdown_label.text = text_value
    _countdown_label_hide_timer = hide_after


func _set_message(text_value: String, duration: float = 0.0) -> void:
    if _message_label != null:
        _message_label.text = text_value
    _wrong_way_message_timer = duration


func _format_time(seconds: float) -> String:
    var total_ms: int = int(seconds * 1000.0)
    var minutes: int = floori(float(total_ms) / 60000.0)
    var secs: int = floori(float(total_ms) / 1000.0) % 60
    var millis: int = total_ms % 1000
    return "%d:%02d.%03d" % [minutes, secs, millis]

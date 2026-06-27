class_name KartStats
extends Resource

@export_group("Identity")
@export var display_name: String = "Standard Bike"
@export var weight_class: String = "Medium"
@export var vehicle_type: String = "Inside-drift bike"
@export_multiline var description: String = "Balanced all-rounder."

@export_group("Drive")
@export var engine_acceleration: float = 12.5
@export var brake_deceleration: float = 34.0
@export var reverse_acceleration: float = 8.0
@export var coast_deceleration: float = 2.0
@export var max_forward_speed: float = 42.0
@export var max_reverse_speed: float = 9.0
@export var rolling_resistance: float = 0.045
@export var air_drag: float = 0.008
@export var aero_downforce: float = 1.10
@export var max_vertical_speed: float = 18.0

@export_group("Steering")
@export var wheelbase: float = 2.15
@export var max_low_speed_steer: float = 0.54
@export var max_high_speed_steer: float = 0.46
@export var steering_response: float = 22.0
@export var high_speed_curvature_scale: float = 1.75
@export var turn_lateral_grip: float = 36.0
@export var lateral_velocity_damping: float = 56.0

@export_group("Lean")
@export var max_lean: float = 0.436332
@export var max_drift_lean: float = 0.523599
@export var lean_response: float = 14.0

@export_group("Suspension")
@export var suspension_rest_length: float = 0.62
@export var suspension_stiffness: float = 15000.0
@export var suspension_compression_damping: float = 2600.0
@export var suspension_rebound_damping: float = 3600.0
@export var suspension_max_force: float = 13000.0
@export var rear_wheel_radius: float = 0.60
@export var front_wheel_radius: float = 0.52

@export_group("Drift")
@export var hop_impulse: float = 3.2
@export var min_drift_speed: float = 3.5
@export var mini_turbo_charge_duration: float = 0.75
@export var super_mini_turbo_charge_duration: float = 1.8
@export var drift_steer_multiplier: float = 1.55
@export var drift_grip_multiplier: float = 1.45
@export var drift_lateral_speed: float = 1.8
@export var drift_lateral_velocity_damping: float = 18.0

@export_group("Boost")
@export var boost_duration: float = 1.25
@export var boost_speed_bonus: float = 17.0
@export var mini_turbo_boost_duration: float = 0.8
@export var super_mini_turbo_boost_duration: float = 1.6
@export var mini_turbo_speed_bonus: float = 11.0
@export var super_mini_turbo_speed_bonus: float = 19.0
@export var boost_acceleration: float = 54.0
@export var boost_fov_bonus: float = 14.0
@export var boost_fx_fov_enabled: bool = true
@export var boost_fx_wind_enabled: bool = true

@export_group("Camera and Visuals")
@export var visual_smoothing: float = 13.0
@export var camera_base_fov: float = 68.0
@export var camera_speed_fov_boost: float = 24.0

@export_group("Obstacle Response")
@export var obstacle_probe_distance: float = 2.1
@export var obstacle_probe_speed_lookahead: float = 0.08
@export var obstacle_wall_normal_max_up: float = 0.55
@export var wall_slide_speed_retention: float = 0.995
@export var wall_bounce_strength: float = 0.16
@export var wall_bounce_max_speed: float = 1.6
@export var wall_unstick_push_speed: float = 0.85

class_name VNEngineAudioChannel
extends Resource

## Command name used in the script, like "music" or "sfx".
@export var command_name: String = ""

## If true, volume changes fade smoothly instead of cutting instantly.
@export var use_fade: bool = false

## Assigned to the player's bus. If the bus doesn't exist yet in Godot,
## it silently falls back to "Master". No crash.
@export var bus_name: String = "Master"

## Base volume in dB when this channel plays. Fades use this as the target
## (silent fade goes to base_volume_db - 40 or -80). Default 0.0 changes nothing.
@export var base_volume_db: float = 0.0

## If true, this channel is rebuilt from the saved state on load, rollback
## and flow start. Channels without it are stopped on those events.
@export var restore_on_load: bool = false

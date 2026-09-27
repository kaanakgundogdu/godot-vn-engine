class_name VNEngineCommandContext
extends RefCounted

var runner: VNEngineStoryRunner
var state: VNEngineStoryState
var script_res: VNEngineStoryScript
var bus: VNEngineCommandBus

var background: VNEngineBackgroundSystem
var characters: VNEngineCharacterLayer
var audio: VNEngineAudioSystem
var video: VNEngineVideoSystem
var camera: VNEngineCameraSystem
var dialog_ui: VNEngineDialogUI

var assets: VNEngineAssetResolver

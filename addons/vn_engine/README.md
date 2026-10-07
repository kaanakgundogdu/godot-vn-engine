# VN Engine

A small visual novel engine for Godot 4.4. You write the story in plain
text scenario files and set up the game with `.tres` resources in the
Inspector. The engine does the rest.
Right now it supports dialogue, characters, backgrounds, choices, flags,
save and load, backlog, auto and skip, gallery, endings and credits.

I tested it in the Godot 4.4 editor and with a Windows export.

The plugin doesn't touch your project. No autoloads, no project
settings, no main scene change. The only thing it adds is a small export
step that puts your scenario files into the build. If you don't use the
engine, it does nothing.

## Try the demo

1. Copy the `addons/vn_engine/` folder into your project, or get it from
   the Asset Library. Keep the same path (`res://addons/vn_engine/`),
   the engine files use it.
2. Open `addons/vn_engine/sample_game/play_sample_game.tscn`.
3. Run that scene.

The sample game is very small. Two chapters of text with choices, flags
and two endings. You don't need to enable the plugin to play it in the
editor.

## Add it to your own game

First, enable the plugin: **Project > Project Settings > Plugins**, turn
on **VN Engine**. Your game will run in the editor without it, but when
you export, the scenario files will be missing and the game will show a
"scenario file not found" error. So turn it on now and forget
about it.

A game is a folder with the same shape as `sample_game/`:

```
res://my_game/
  config/      game.tres and the other .tres files (chapters, characters, endings ...)
  scenario/    one folder per chapter with .txt scenario files
  assets/      your images, music and videos
```

The easiest start is to copy `sample_game/` and change it.
There is no guide for the scenario syntax yet. Read
`sample_game/scenario/chapter1/scenario1.txt`, it shows the basics.

The engine runs inside one node: `VNEngineMain`. When this node is in
the tree, the engine works. When it is removed, the engine is gone.
You can add it in three ways.

### 1. The VN is the whole game

Create a new scene, add a `VNEngineMain` node as the root (**Add Node**,
search "VNEngineMain"), set `content_root` to your folder and make it
your main scene.

You can also make an inherited scene from
`res://addons/vn_engine/src/flow/scenes/vn_main.tscn`
(**Scene > New Inherited Scene**), it is the same thing. The demo scene
`play_sample_game.tscn` is made this way. Don't edit `vn_main.tscn`
directly, it belongs to the addon.

### 2. The VN is one part of your game

Add a `VNEngineMain` node to one of your own scenes, like any other node.
Set `content_root`, and if you only want to play one chapter, set
`start_mode` to `chapter`. See
[Using the engine from code](#using-the-engine-from-code) for how to know
when the chapter is over.

### 3. Start it from code

Set the values before you add the node to the tree:

```gdscript
func start_vn() -> void:
	var vn := VNEngineMain.new()
	vn.content_root = "res://my_game/"
	add_child(vn)
```

### Settings

`content_root` is the only setting you must set. The others work fine
as they are:

- `save_folder`: where save slots go. Default: `user://vn_engine/{game_id}/saves/`
- `settings_file`: player settings like volume, text speed and keys. Default: `user://vn_engine/{game_id}/settings.json`
- `verbose_log`: extra logs in debug builds. Off by default.
- `start_mode`: what the player sees first.
  - `boot`: splash screens, then the title screen. This is the default.
  - `title`: the title screen, no splash screens.
  - `chapter`: goes right into a chapter, no title screen.
- `start_chapter`: the chapter id for `start_mode = chapter`. Empty means
  the first chapter in `game.tres`.
- `return_to_title_on_finish`: on by default, the engine goes to the next
  chapter or back to the title after a chapter or an ending. Turn it off
  if the VN is one part of your game. Then the engine stops there and only
  sends a signal, and you decide what happens next.
- `design_resolution`: the resolution the UI is made for. Default: 1920x1080.
- `manage_window_scaling`: scales the window to `design_resolution` while the VN runs. On by default.

`{game_id}` is the `game_id` in your `game.tres`. So every game gets its
own saves and settings, and the engine never writes over your own save
files.

See [Config files](#config-files) for what each file does.


## Config files


A `.tres` file is a Godot resource saved as text. It keeps data, not code.
Double click it in the FileSystem dock and edit it in the Inspector.
Each config file uses one engine class from `src/defs/`. A file that starts
with `_` is a list: it only collects the other files in its folder.

Note: I'm not sure yet if config files are the best way to set up a
game, but they work fine for now. Maybe later I'll make an editor tool
for them.

```
config/
  game.tres
  chapters/      chapter1.tres, chapter2.tres ...
  characters/    _characters.tres, qaan.tres, ely.tres ...
  flags/         _flags.tres, warmth.tres ...
  endings/       ending_warm.tres, ending_plain.tres ...
  credits/       _credits.tres, 01_story.tres ...
  asset_map/     _asset_map.tres, background.tres ...
  screens/       title.tres
                 extras.tres, ui.tres   (optional)
  boot/          _boot.tres, 01_logo.tres ...   (optional)
```

| File | Class | What it does |
|---|---|---|
| `game.tres` | `VNEngineGameManifest` | The main file. Game id, first chapter and links to all the lists. |
| `boot/_boot.tres` | `VNEngineBootDef` | Optional. List of splash screens before the title. |
| `boot/01_logo.tres` | `VNEngineBootScreenDef` | One splash screen: an image or a video, how long it stays, fade time. |
| `chapters/chapter1.tres` | `VNEngineChapterDef` | One chapter: title, scenario file, intro, music, next chapter or branches, extra assets to preload. |
| `characters/_characters.tres` | `VNEngineCast` | List of all characters. |
| `characters/qaan.tres` | `VNEngineCastMember` | One character: id for scenarios, shown name, name color, default sprite. |
| `flags/_flags.tres` | `VNEngineFlagList` | List of all flags (story variables). |
| `flags/warmth.tres` | `VNEngineFlagDef` | One flag: type, start value, scope (one save or global), min and max. |
| `endings/ending_warm.tres` | `VNEngineEndingDef` | One ending: how to reach it, CG, music, credits and what it unlocks. |
| `credits/_credits.tres` | `VNEngineCreditsDef` | Credits screen: scrolling or video, speed, music and its sections. |
| `credits/01_story.tres` | `VNEngineCreditsSection` | One credits block: a role and its names. |
| `asset_map/_asset_map.tres` | `VNEngineAssetMap` | List of asset folders. |
| `asset_map/background.tres` | `VNEngineAssetMapEntry` | Folder and file types for one asset kind, so scenarios can use short names. |
| `screens/title.tres` | `VNEngineTitleScreenDef` | Title screen: background, music, logo, menu place, when to show Extras and Chapter Select. |
| `screens/extras.tres` | `VNEngineExtrasDef` | Optional. Extras menu: which pages to show and how locked items look. |
| `screens/ui.tres` | `VNEngineUiDef` | Optional. Small UI options: confirm dialogs, backdrop color, name colors in the log. |

`sample_game/config/` is the simplest working set. It has no `boot`, `extras`
or `ui` files, so these are not needed to start.

### Preloading

Before a chapter starts, the engine reads its scenario and loads the
backgrounds, CGs, music and sprites it uses, so there is no small freeze
in the middle of the chapter. If a chapter shows something that is not
written in the scenario (for example an image you show from your own
code), add it to `preload_assets` in the chapter file. You can write an
asset id like in scenarios (`room_night`) or a full path
(`res://my_game/assets/...`).


## Using the engine from code

While the VN is running, you can reach its parts from anywhere with
`VNEngineMain`:

- `VNEngineMain.game()` for the game flow: start a new game, go to a
  chapter, return to title, quit.
- `VNEngineMain.saves()` for save slots, like `save_game(state, slot)`.
- `VNEngineMain.save_data()` for things that stay between saves:
  unlocked CGs and music, seen endings, global flags, seen lines.
- `VNEngineMain.settings()` for the player settings.
- `VNEnginePaths` for the paths of the running game's files.

They are loaded when the VN starts and written to disk when it closes.
When no VN is running, they return `null`.

### Signals

`VNEngineMain` sends these signals, so you can connect them in the
editor (Node dock) or from code:

- `chapter_finished(chapter_id)`: a chapter is over.
- `ending_reached(ending_id)`: the player reached an ending.
- `returned_to_title`: the player went back to the title screen.
- `quit_requested`: the player pressed "Quit".

If nothing is connected to `quit_requested`, the engine closes the game.
If you connect to it, the engine doesn't quit and lets you decide.

Other signals you may need: `saved(slot_id)` and `loaded(slot_id)` on
`saves()`, and `global_changed` on `save_data()`.

### Play one chapter

If the VN is only one part of your game, you probably want to play a
chapter, get a signal when it ends and go back to your own game:

```gdscript
func talk_to_shopkeeper() -> void:
	var vn := VNEngineMain.new()
	vn.content_root = "res://my_game/"
	vn.start_mode = "chapter"
	vn.start_chapter = "shop_talk"
	vn.return_to_title_on_finish = false
	vn.chapter_finished.connect(_on_talk_finished.bind(vn), CONNECT_ONE_SHOT)
	add_child(vn)

func _on_talk_finished(chapter_id: String, vn: VNEngineMain) -> void:
	vn.queue_free()
	# back to your own game here
```

If the node is already running, `play_chapter("chapter_id")` starts
another chapter in it.

The ending records (seen endings, unlocked CGs) are still saved in this
mode, only the screens after the ending are not shown.

## Export

Things to know before you export:

- **The plugin must be enabled.** During export the engine turns every
  scenario `.txt` file into a binary file and puts that into the `.pck`
  instead of the text. In the editor nothing changes, you keep writing
  `.txt` files. If the plugin is off, the scenarios are left out and the
  game shows a "scenario file not found" error.
- **Scenario files are hidden, not locked.** The player can't open the
  scenario as text, but a person who really wants to can still read the
  `.pck` with some tools. If you want more, Godot can encrypt the `.pck`,
  but you need to build your own export templates with a key for that
  (see "Compiling with PCK encryption key" in the Godot docs). No method
  is fully safe.
- **Save folder.** By default saves go to
  `AppData/Roaming/Godot/app_userdata/<project name>/vn_engine/` on
  Windows. If you want a folder with your game's name, turn on
  **Project Settings > Application > Config > Use Custom User Dir**.
- **`sample_game/` is left out of release builds**, unless your main
  scene is inside it. So it doesn't make your game bigger. Debug builds
  still have it.
- **Export mode.** With "Export all resources" (the default) you don't
  need to do anything. With "Export selected scenes", Godot doesn't follow
  `class_name` references, so add `addons/vn_engine/*` and your game
  folder (for example `my_game/*`) to the include filter.
- **Editor tools in release builds.** The scripts in `src/tools/` are
  only for the editor, but the engine can't remove them from the build
  on its own (Godot handles scripts before our export step runs). They
  are about 40 KB and do nothing in the game. If you want them out, add
  `addons/vn_engine/src/tools/*` to the exclude filter in your export
  preset.

## License

MIT, see `LICENSE`.

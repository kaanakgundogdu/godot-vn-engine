<p align="left">
  <img src="readme_files/images/icons/cat_logo_mono_256.png" width="128" alt="VN Engine icon">
</p>

# VN Engine

A small visual novel engine for Godot 4.4. You write the story in plain text
files, set up the game with `.tres` resources and run it inside one scene.

Dialogue, characters, backgrounds, choices, flags, save and load, backlog,
auto and skip, rollback, gallery, endings and credits.

The plugin doesn't change your project. No autoloads, no project settings,
no main scene change.

## Getting started

**1.** Put the `vn_engine` folder inside your project's `addons/` folder, or install it from the Asset Library.

<p align="left"><img src="readme_files/images/vn_eng_%20(1).png" width="800" alt="addons folder"></p>

**2.** Open **Project > Project Settings**.

<p align="left"><img src="readme_files/images/vn_eng_%20(2).png" width="800" alt="project menu"></p>

**3.** Go to the **Plugins** tab and turn on **VN Engine**.

<p align="left"><img src="readme_files/images/vn_eng_%20(3).png" width="800" alt="plugins tab"></p>

**4.** Open `addons/vn_engine/sample_game/play_sample_game.tscn` and press **F6** to run it.

<p align="left"><img src="readme_files/images/vn_eng_%20(4).png" width="800" alt="sample scene"></p>

## What you get

The sample game starts at the title screen.

<p align="left"><img src="readme_files/images/vn_eng_%20(5).png" width="640" alt="title screen"></p>

Players can change display, audio and text settings.

<p align="left"><img src="readme_files/images/vn_eng_%20(6).png" width="640" alt="settings"></p>

Every key can be changed in the Controls tab.

<p align="left"><img src="readme_files/images/vn_eng_%20(7).png" width="640" alt="controls"></p>

The dialogue box has Auto, Skip, Log, Save, Load, Settings and Menu buttons.

<p align="left"><img src="readme_files/images/vn_eng_%20(8).png" width="640" alt="dialogue box"></p>

Press **F3** in debug builds to see the current chapter, line and flags.

<p align="left"><img src="readme_files/images/vn_eng_%20(9).png" width="640" alt="debug panel"></p>

## Next steps

To make your own game, read the plugin's own
[README](addons/vn_engine/README.md). It explains the folder layout, the
config files and how to start the engine from code.

## License

MIT, see [LICENSE](LICENSE).

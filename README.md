# Script IDE

Transforms the Script UI into an IDE like UI. Tabs are used for navigating between scripts. The default Outline got an overhaul and now shows all members of the script (not just methods) with unique icons for faster navigation.

Features:
- Scripts are now shown as Tabs inside a TabContainer (No Script List)
- The Outline is on the right side (can be changed to be on the left side again)
- The Outline got an overhaul and shows more than just the methods of the script. It includes the following types with a unique icon:
	- Classes (Red Square)
	- Constants (Red Circle)
	- Signals (Yellow)
	- Export variables (Orange)
	- (Static) Variables (Red)
	- Engine callback functions (Blue)
	- (Static) Functions (Green)
- You can now search for variables/methods by pressing `CTRL/CMD/META + O` (can be changed, see below). The Outline is reused in this case
- You can navigate through the Outline with the arrow keys and scroll to the selected item by pressing `ENTER`
- The Outline can be toggled via `File -> Toggle Scripts Panel`. This will hide or show it
- The plugin is written with performance in mind, everything is very fast and works without any lags or stuttering.

There are mutliple properties that can be configured by your needs.

The shortcut can be changed in the first lines of `script-ide/plugin.gd`:
- `OUTLINE_POPUP_TRIGGER` / `OUTLINE_POPUP_TRIGGER_ALT` = Shortcut to trigger the Outline popup (default=CTRL+O / META+O)

The following settings can be changed in the Project Settings under `plugin/script-ide`:
- `outline_position_right` = Flag to control whether the outline should be on the right or on the left side of the script editor (default=true)
- `hide_private_members` = Flag to control whether private members (methods/variables/constants starting with '_') should be hidden in the Outline or not (default=false)

![Example of the outline](https://github.com/godotengine/godot/assets/66004280/30d04924-ba53-415d-b796-92b2fc086ff9)

![Example of the outline popup](https://github.com/godotengine/godot/assets/66004280/cad0e00e-dbb6-4d3d-980b-c36da6af2cb8)

![Example of the project settings](https://github.com/godotengine/godot/assets/66004280/934a4233-1d9f-4c25-853b-90911c87c506)

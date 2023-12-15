# Script IDE

Transforms the Script UI into an IDE like UI. Tabs are used for navigating between scripts. The default Outline got an overhaul and now shows all members of the script (not just methods) with unique icons for faster navigation.

Features:
- Scripts are now shown as Tabs inside a TabContainer (No Script List)
- The Outline is on the right side (can be changed to be on the left side again)
- The Outline got an overhaul and shows more than just the methods of the script. It includes the following members with a unique icon:
	- Classes (Red Square)
	- Constants (Red Circle)
	- Signals (Yellow)
	- Export variables (Orange)
	- (Static) Variables (Red)
	- Engine callback functions (Blue)
	- (Static) Functions (Green)
- All the different members of the script can be hidden or made visible again. This allows fine control what should be visible (e.g. only signals, functions, ...)
- There is also the possibility to hide private members, this is all members starting with a '_'
- The Outline can be opened as Popup with a defined shortcut (more below). This allows to quickly search for a specific member and scroll to it
- You can navigate through the Outline with the arrow keys and scroll to the selected item by pressing `ENTER`
- The Outline can be toggled via `File -> Toggle Scripts Panel`. This will hide or show it
- The plugin is written with performance in mind, everything is very fast and works without any lags or stuttering.

All settings can be changed in the `Editor Settings` under `Plugin` -> `Script Ide`:
- `Open Outline Popup` = Shortcut to control how the Outline Popup should be triggered (default=CTRL+O or META+O)
- `Outline position right` = Flag to control whether the outline should be on the right or on the left side of the script editor (default=true)
- `Hide private members` = Flag to control whether private members (methods/variables/constants starting with '_') should be hidden in the Outline or not (default=false)
- All outline visibility settings

![Example of the outline](https://github.com/godotengine/godot/assets/66004280/30d04924-ba53-415d-b796-92b2fc086ff9)

![Example of the outline popup](https://github.com/godotengine/godot/assets/66004280/cad0e00e-dbb6-4d3d-980b-c36da6af2cb8)

![Example of the editor settings](https://github.com/godotengine/godot/assets/66004280/103ba1bc-a6c7-4b48-8691-fa59ba2b833d)

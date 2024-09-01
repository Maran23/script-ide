# Script IDE

Transforms the Script UI into an IDE like UI. Tabs are used for navigating between scripts.
The default Outline got an overhaul and now shows all members of the script (not just methods) with unique icons for faster navigation.
Enhanced keyboard navigation for Scripts and Outline.

Features:
- Scripts are now shown as Tabs inside a TabContainer
- The Outline got an overhaul and shows more than just the methods of the script. It includes the following members with a unique icon:
	- Classes (Red Square)
	- Constants (Red Circle)
	- Signals (Yellow)
	- Export variables (Orange)
	- (Static) Variables (Red)
	- Engine callback functions (Blue)
	- (Static) Functions (Green)
- All the different members of the script can be hidden or made visible again. This allows fine control what should be visible (e.g. only signals, (Godot) functions, ...)
- The Outline can be opened in a Popup with a defined shortcut for quick navigation between methods
- You can navigate through the Outline with the `ARROW` keys (or `PAGE_UP/PAGE_DOWN`) and scroll to the selected item by pressing `ENTER`
- Scripts can be opened in a Popup with a defined shortcut or when clicking the three dots on the top right of the TabContainer for quick navigation between scripts
- The plugin is written with performance in mind, everything is very fast and works without any lags or stuttering.

Customization:
- The Outline is on the right side (can be changed to be on the left side again)
- The Outline can be toggled via `File -> Toggle Scripts Panel`. This will hide or show it
- There is also the possibility to hide private members, this is all members starting with a `_`
- The Script ItemList is not visible by default, but can be made visible again

All settings can be changed in the `Editor Settings` under `Plugin` -> `Script Ide`:
- `Open Outline Popup` = Shortcut to control how the Outline Popup should be triggered (default=CTRL+O or META+O)
- `Outline Position Right` = Flag to control whether the outline should be on the right or on the left side of the script editor (default=true)
- `Hide Private Members` = Flag to control whether private members (methods/variables/constants starting with '_') should be hidden in the Outline or not (default=false)
- `Open Script Popup` = Shortcut to control how the Script Popup should be triggered (default=CTRL+U or META+U)
- `Script List Visible` = Flag to control whether the script list should still be visible or not (above the outline) (default=false)
- All outline visibility settings

![Example of the Outline](https://github.com/user-attachments/assets/1729cb2b-01ae-4365-b77a-45edcb94b978)

![Example of the Outline Popup](https://github.com/user-attachments/assets/995c721f-9708-40d9-a4e8-57b1a99e9c29)

![Example of the TabContainer Script ItemList Popup](https://github.com/user-attachments/assets/484d498c-bd1c-4c77-a693-ac31a8500fbe)

![Example of the Script ItemList Popup](https://github.com/user-attachments/assets/bb976604-6049-4ce1-a28e-377fc62899f6)

![Example of the plugin editor settings](https://github.com/user-attachments/assets/0450e423-bc49-4076-862b-c95a62190df1)

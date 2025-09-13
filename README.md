# Script IDE

Transforms the Script UI into an IDE like UI.
Tabs are used for navigating between scripts.
The default Outline got an overhaul and now shows all members of the script (not just methods) with unique icons for faster navigation.
Enhanced keyboard navigation for Scripts and Outline.
Fast quick search functionality.
Quick function Override functionality.

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
		- Setter functions (Green circle, with an arrow inside it pointing to the right)
		- Getter functions (Green circle, with an arrow inside it pointing to the left)
- All the different members of the script can be hidden or made visible again by the outline filter. This allows fine control what should be visible (e.g. only signals, (Godot) functions, ...)
- A `Right Click` enables only the clicked filter, another `Right Click` will enable all filters again
- The Outline can be opened in a Popup with a defined shortcut for quick navigation between methods
- You can navigate through the Outline with the `Arrow` keys (or `Page up/Page down`) and scroll to the selected item by pressing `ENTER`
- Scripts can be opened in a Popup with a defined shortcut or when clicking the three dots on the top right of the TabContainer for quick navigation between scripts
- The currently edited script is automatically selected in the Filesystem Dock
- Files can be quickly searched by the Quick Search Popup with `Shift`+`Shift`
- You can find and quickly override any method from your super classes with `Alt`+`Ins`
- The plugin is written with performance in mind, everything is very fast and works without any lags or stuttering

Customization:
- The Outline is on the right side (can be changed to be on the left side again)
- The Outline can be toggled via `File -> Toggle Scripts Panel`. This will hide or show it
- The order in the Outline can be changed
- There is also the possibility to hide private members, this is all members starting with a `_`
- The Script ItemList is not visible by default, but can be made visible again

All settings can be changed in the `Editor Settings` under `Plugin` -> `Script Ide`:
- `Open Outline Popup` = Shortcut to control how the Outline Popup should be triggered (default=CTRL+O or META+O)
- `Outline Position Right` = Flag to control whether the outline should be on the right or on the left side of the script editor (default=true)
- `Outline Order` = List which specifies the order of all different types in the Outline
- `Hide Private Members` = Flag to control whether private members (methods/variables/constants starting with '_') should be hidden in the Outline or not (default=false)
- `Open Script Popup` = Shortcut to control how the Script Popup should be triggered (default=CTRL+U or META+U)
- `Script List Visible` = Flag to control whether the script list should still be visible or not (above the outline) (default=false)
- `Script Tabs Visible` = Flag to control whether the script tabs should be visible or not (default=true)
- `Script Tabs Position Top` = Flag to control whether the script tabs should be on the top or on the bottom (default=true)
- `Script Tabs Close Button Always` = Flag to control whether the script tabs should always have the close button or only the select tab (default=false)
- `Auto Navigate in FileSystem Dock` = Flag to control whether the script that is currently edited should be automatically selected in the Filesystem Dock (default=true)
- `Open Quick Search Popup` = Shortcut to control how the Quick Search Popup should be triggered (default=Shift+Shift, double press behavior is hardcoded for now)
- `Open Override Popup` = Shortcut to control how the Override Popup should be triggered (default=Alt+Ins)
- `Cycle Tab forward` = Shortcut to cycle the script tabs in the forward direction (only works in the 'Script' Editor Tab) (default=CTRL+TAB)
- `Cycle Tab backward` = Shortcut to cycle the script tabs in the backward direction (only works in the 'Script' Editor Tab) (default=CTRL+SHIFT+TAB)
- All outline visibility settings

![Example of the Outline](https://github.com/user-attachments/assets/1729cb2b-01ae-4365-b77a-45edcb94b978)

![Example of the Outline Popup](https://github.com/user-attachments/assets/995c721f-9708-40d9-a4e8-57b1a99e9c29)

![Example of the TabContainer Script ItemList Popup](https://github.com/user-attachments/assets/484d498c-bd1c-4c77-a693-ac31a8500fbe)

![Example of the Script ItemList Popup](https://github.com/user-attachments/assets/bb976604-6049-4ce1-a28e-377fc62899f6)

![Example of the Quick Search Popup](https://github.com/user-attachments/assets/01141f05-e07c-4059-8d6f-e4c7490cbd40)

![Example of the Plugin Editor Settings](https://github.com/user-attachments/assets/0450e423-bc49-4076-862b-c95a62190df1)

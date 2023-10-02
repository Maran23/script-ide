# Script IDE

Script IDE is a plugin for Godot that transform the Script UI into an IDE like UI.

The following things are changed:
- Scripts are now shown as Tabs inside a TabContainer (No Script List)
- The Outline is on the right side
- The Outline got an overhaul and shows more than just the methods of the script. 
It includes the following types with a unique icon:
	- Classes (Red Square)
	- Constants (Red with a C)
	- Signals (Yellow)
	- Export variables (Orange)
	- Variables (Red)
	- Engine callback functions (Blue)
	- Functions (Green)
- You can now search for variables/methods by pressing CTRL/CMD + O (can be changed in the addon code). The Outline is reused in this case
  - You can navigate through the Outline with the arrow keys
- The Outline can be toggled via 'File -> Toggle Scripts Panel'. This will actually hide or show the Outline

![Example of the outline](https://user-images.githubusercontent.com/66004280/271794386-d60978a8-4db0-4798-84e1-e5e2468162dd.png)

![Example of the outline popup](https://user-images.githubusercontent.com/66004280/271794388-fa44cb4e-e90c-4967-bd54-3993fb895d69.png)

# WieldingProcess

This is an example Powershell module using [WieldingAnsi](https://github.com/Wielding/WieldingAnsi) to create a very primitive `htop` like process viewer for Windows.

This project is currently my playground for what is possible using [WieldingAnsi](https://github.com/Wielding/WieldingAnsi) and helps determine what functionality I will add to that project.

My intention is not to fully implement anything process related so don't expect an `htop` replacement here.  My goal is to implement text base UI features in a Powershell console script. I am just using `htop` as a reference since it has a nice console interface.  Maybe one day it will be a full featured process monitor but I doubt it.  I will probably move onto something else before it ever gets that far.  

This module is known to work using [Windows Terminal](https://github.com/microsoft/terminal).  Any other console running Powershell may have unexpected behavior or not work at all.  For example the ASNI escape codes for hiding/showing the cursor do not work under the default Powershell Core console but work fine under [Windows Terminal](https://github.com/microsoft/terminal).  

It implements some handy ANSI escape sequences such as:

1. Switching to a secondary screen buffer to display the processes and then switching back to the original buffer when `Ctrl-C` is press which restores your console screen contents.
2. Moving the cursor to the top corner of the screen to update the screen.
3. Erasing lines to clear old output.
4. Hiding the cursor upon execution and then restoring when upon exit.

I have also implemented some basic keyboard shortcuts.

* `Q`, `F10`, `CTRL-C` - Quit
* `CTRL-P` - Sort by CPU percent
* `CTRL-N` - Sort by Name
* `CTRL-D` - Toggle sort direction (Ascending,Descending)

To give it a try 

```powershell
git clone https://github.com/Wielding/WieldingProcess
cd WieldingProcess
Install-Module WieldingAnsi # this is a required dependency
Import-Module WieldingAnsi
Import-Module ./WieldingProcess.psm1
Show-ProcessExt -Continuous -SortProperty CPU -MinCpu 0.01 -SortDirection Descending
```

This will display an `htop` like continuously updating screen with as many processes as can fit within your current console height and have at least 0.01% CPU usage.


# WieldingProcess

**Do not rely on functionality in this project. I will break it eventually.**

This is an example Powershell module using [WieldingAnsi](https://github.com/Wielding/WieldingAnsi) to create a very primitive `htop` like process viewer for Windows.

This project is currently my playground for what is possible using [WieldingAnsi](https://github.com/Wielding/WieldingAnsi) and helps determine what functionality I will add to that project.

My intention is not to fully implement anything process related so don't expect an `htop` replacement here.  My goal is to implement text base UI features in a Powershell console script. I am just using `htop` as a reference here.

The CPU usage resolution is very poor due to limitations in PowerShell only code related to process information. I have looked for alternative methods to get CPU percentage per process wiht PowerSHell and have not found any yet.

This module has only been tested with [Powershell Core 7.0+](https://github.com/powershell/powershell) and [Windows Terminal](https://github.com/microsoft/terminal).  Any other console running any other Powershell may have unexpected behavior or not work at all.


It has process name autocompletion enabled for the first parameter.

Thare are some keyboard shortcuts.

* `Q`, `F10` - Quit
* `CTRL-P` - Sort by CPU percent
* `CTRL-N` - Sort by Name
* `CTRL-I` - Sort by Process ID
* `CTRL-R` - Sort by Parent Process ID
* `CTRL-D` - Toggle sort direction (Ascending,Descending)

To give it a try 

```powershell
git clone https://github.com/Wielding/WieldingProcess
cd WieldingProcess
Install-Module WieldingAnsi # this is a required dependency from the PowerShell Gallery
Import-Module WieldingAnsi
Import-Module ./WieldingProcess.psm1
Show-ProcessExt -Continuous -MinCpu 0.01
```

This will display a continuously updating screen with as many processes that register CPU usage as can fit within your current console height until the `Q` or `F10` key is hit.

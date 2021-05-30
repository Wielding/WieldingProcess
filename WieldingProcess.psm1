Import-Module WieldingAnsi

enum SortProperty {
    None
    CPU
    Name
    WS
    Id
    ParentId
}

enum SortDirection {
    Ascending
    Descending
}

enum KeyCommand {
    Quit
    SortCpu
    SortName
    SortMemory
    SortId
    SortParentId
    ToggleDirection
    ToggleColor
}


[console]::TreatControlCAsInput = $true

class ProcessInfo {
    $Id
    $ParentId
    [string]$Name
    [string]$Description
    [float]$CPU
    [Int64]$PM
    [Int64]$WS 
    [Int64]$Threads
}

function Get-ProcessExt {
    param (
        [string]$Name = "*"
    )

    $processorCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $processInfo = @()
    $cpuPercentages = @{}
    $cimProcessList = @{}
    $processList = @{}

    (get-CimInstance win32_PerfFormattedData_PerfProc_Process ) | ForEach-Object -Process {
        $cpuPercentages[[int]($_.IDProcess)] = [Decimal]::Round(($_.PercentProcessorTime / $processorCount), 2)
    }      

    Get-Process -Name $Name -ErrorAction SilentlyContinue | ForEach-Object -Process {
        $processList[$_.Id] = $_
    } 

    Get-CimInstance Win32_Process | ForEach-Object -Process {
        $cimProcessList[[int]($_.ProcessId)] = $_
    }

    foreach ($p in $processList.GetEnumerator()) {

        $i = New-Object -TypeName ProcessInfo
        $process = $processList[$p.Name]
        $i.Id = $process.Id
        $i.Name = $process.Name
        $i.CPU = $cpuPercentages[$process.Id]
        $i.PM = $process.PrivateMemorySize64
        $i.WS = $process.WS
        $i.ParentId = $cimProcessList[$process.Id].ParentProcessId
        $i.Threads = $cimProcessList[$process.Id].ThreadCount
        $i.Description = $process.Description

        $processInfo += $i
    }

    $processInfo
}    

function Get-KeyCommand {
    param (
        [object]$Map,
        [System.ConsoleKeyInfo]$key
    ) 

    if ($Map.ContainsKey($key.Modifiers)) {
        return $Map[$key.Modifiers][$key.Key]
    }

    return $Map["None"][$key.Key]
}

function Show-ProcessExt {
    param (
        [string]$Name = "*",
        [float]$MinCpu = 0.0,
        [SortProperty]$SortProperty = [SortProperty]::CPU,
        [SortDirection]$SortDirection = [SortDirection]::Descending,
        [switch]$HideHeader,
        [switch]$Continuous,
        [int]$Delay = 0
    )


    $KeyMap = @{
        "None"                                                                                                   = @{
            [ConsoleKey]::Q   = [KeyCommand]::Quit
            [ConsoleKey]::F10 = [KeyCommand]::Quit
        }
        [System.ConsoleModifiers]::Control                                                                       = @{
            # [ConsoleKey]::C = [KeyCommand]::Quit
            [ConsoleKey]::P = [KeyCommand]::SortCpu
            [ConsoleKey]::N = [KeyCommand]::SortName
            [ConsoleKey]::W = [KeyCommand]::SortMemory
            [ConsoleKey]::I = [KeyCommand]::SortId
            [ConsoleKey]::R = [KeyCommand]::SortParentId
            [ConsoleKey]::D = [KeyCommand]::ToggleDirection
            
        }

        ([System.ConsoleModifiers]::Shift + [System.ConsoleModifiers]::Alt + [System.ConsoleModifiers]::Control) = @{
            [ConsoleKey]::X = [KeyCommand]::Quit
        }
    }


    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "EraseDisplay" -Value "`e[2J" -Force
    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "MoveHome" -Value "`e[0;0H" -Force
    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "EraseLine" -Value "`e[K" -Force
    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "HideCursor" -Value "`e[?25l" -Force
    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "ShowCursor" -Value "`e[?25h" -Force
    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "EnableAlt" -Value "`e[?1049h" -Force
    Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "DisableAlt" -Value "`e[?1049l" -Force


    if ($Continuous) {
        Write-Wansi "{:EnableAlt:}{:EraseDisplay:}{:HideCursor:}"
    }

    $keepShowing = $true
    while ($keepShowing) {
        if ($Continuous) {
            Write-Wansi "{:MoveHome:}"
        }

        $keepShowing = $Continuous -and $keepShowing
        $ps = Get-ProcessExt -Name $Name
    
        if ($SortProperty -ne [SortProperty]::None) {
            if ($SortDirection -eq [SortDirection]::Descending) {
                $ps = $ps | Sort-Object -Property "$SortProperty" -Descending
            }
            else {
                $ps = $ps | Sort-Object -Property "$SortProperty"
            }
        }

        $linesDisplayed = 0

        if (-not $HideHeader) {
            $linesDisplayed++
            Write-Host ("{0}{1}{2} {3}{4}{5}{6}`n" -f
                (ConvertTo-AnsiString "{:F15:}{:B6:}Id" -PadRight 8).Value,
                (ConvertTo-AnsiString "ParentId" -PadRight 8).Value,
                (ConvertTo-AnsiString "CPU%" -PadLeft 8).Value,
                (ConvertTo-AnsiString "WS(KB)" -PadLeft 8).Value,
                (ConvertTo-AnsiString "Thd" -PadLeft 5).Value,
                (ConvertTo-AnsiString " Name" -PadRight 40).Value,
                (ConvertTo-AnsiString " Description{:EraseLine:}" -PadRight 40).Value,
                (ConvertTo-AnsiString "{:R:}").Value
            ) -NoNewline
        }

        $maxProcesses = $ps.Length

        if ($Continuous) {
            $maxProcesses = $Host.UI.RawUI.WindowSize.Height
        }

        foreach ($p in $ps) {
            if ($p.Id -ne 0) {
                if (($p.CPU -ge $MinCpu) -or ($null -eq $p.CPU)) {
                    if ($null -ne $p.ParentId) {
                        $linesDisplayed++                        

                        if ($Continuous -and ($linesDisplayed -ge $maxProcesses)) {
                            break
                        }

                        Write-Host ("{0}{1}{2} {3}{4}{5}{6}`n" -f
                            (ConvertTo-AnsiString "{:R:}{:F15:}$($p.Id){:R:}" -PadRight 8).Value,
                            (ConvertTo-AnsiString "{:F15:}$($p.ParentId){:R:}" -PadRight 8).Value,
                            (ConvertTo-AnsiString "{:F10:}$($p.CPU){:R:}" -PadLeft 8).Value,
                            (ConvertTo-AnsiString "{:F166:}$([int64]($p.WS / 1024)){:R:}" -PadLeft 8).Value,
                            (ConvertTo-AnsiString "{:F32:}$([int64]($p.Threads)){:R:}" -PadLeft 5).Value,
                            (ConvertTo-AnsiString "{:F3:} $($p.Name){:R:}" -PadRight 40).Value,
                            (ConvertTo-AnsiString "{:F8:} $($p.Description){:R:}{:EraseLine:}" -PadRight 40).Value.SubString(0, 40)
                        ) -NoNewline
                    }
                }
            }
        }

        if ($Continuous) {
            $linesToClear = $host.Ui.RawUI.WindowSize.Height - $linesDisplayed - 2

            while ($linesToClear -gt 0) {
                Write-Wansi "{:R:}{:EraseLine:}`n"                    
                $linesToClear--
            }            

            $load = (Get-CimInstance Win32_Processor | Select-Object -Property LoadPercentage).LoadPercentage
            $loadColor = "{:F22:}"

            if ($load -gt 25) {
                $loadColor = "{:F3:}"
            }

            if ($load -gt 50) {
                $loadColor = "{:F1:}"
            }

            $moveToLastLine = "`e[$($host.Ui.RawUI.WindowSize.Height);0H"
            Write-Wansi "$moveToLastLine{:F15:}{:B6:}'{:F3:}Q{:F15:}' or '{:F3:}F10{:F15:}' to quit | Sort:[$SortProperty`:$SortDirection] | Load:[$loadColor$load{:F15:}]{:EraseLine:} {:R:}"

            if ([Console]::KeyAvailable) { 
                $keyHit = [Console]::ReadKey("IncludeKeyUp,NoEcho")

                $kc = Get-KeyCommand $KeyMap $keyHit

                switch ($kc) {
                    ([KeyCommand]::Quit) {
                        Write-Wansi "{:DisableAlt:}{:ShowCursor:}"
                        return                                        
                    }

                    ([KeyCommand]::ToggleDirection) {
                        if ($SortDirection -eq [SortDirection]::Ascending) {
                            $SortDirection = [SortDirection]::Descending
                        }
                        else {
                            $SortDirection = [SortDirection]::Ascending
                        }
                    }

                    ([KeyCommand]::SortName) {
                        $SortProperty = [SortProperty]::Name
                    }

                    ([KeyCommand]::SortCpu) {
                        $SortProperty = [SortProperty]::CPU
                    }

                    ([KeyCommand]::SortMemory) {
                        $SortProperty = [SortProperty]::WS
                    }

                    ([KeyCommand]::SortParentId) {
                        $SortProperty = [SortProperty]::ParentId
                    }

                    ([KeyCommand]::SortId) {
                        $SortProperty = [SortProperty]::Id
                    }

                    ([KeyCommand]::ToggleColor) {
                        $Wansi.Enabled = (-not $Wansi.Enabled )
                    }
                }
            }

            if ($Delay -gt 0) {
                Start-Sleep -Seconds $Delay
            }
        }
    }
}


$processCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-Process "$wordToComplete*" | Sort-Object -Property ProcessName | ForEach-Object -Process { if ($_.ProcessName.ToUpper().StartsWith($wordToComplete.ToUpper())) { "$($_.ProcessName)" } }
}

Register-ArgumentCompleter -CommandName Get-ProcessExt -ParameterName Name -ScriptBlock $processCompleter
Register-ArgumentCompleter -CommandName Show-ProcessExt -ParameterName Name -ScriptBlock $processCompleter

Export-ModuleMember -Function Out-Default, 'Get-ProcessExt'
Export-ModuleMember -Function Out-Default, 'Show-ProcessExt'

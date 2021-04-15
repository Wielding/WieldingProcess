Import-Module WieldingAnsi

enum SortProperty {
    None
    CPU
    Name
    WS
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

    $CpuCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

    $pi = @()
    $cpu = @{}

    (Get-Counter "\Process($Name)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples  | ForEach-Object -Process {
        $cpu[$_.InstanceName] = [Decimal]::Round(($_.CookedValue / $CpuCores), 2)
    }

    $gp = Get-Process -Name $Name

    foreach ($p in $gp) {
        $add = $true

        if (-not $cpu.ContainsKey($p.Name)) {
            $cpu[$p.Name] = -1
        }

        if ($add) {
            $i = New-Object -TypeName ProcessInfo
            $i.Id = $p.Id
            $i.Name = $p.Name
            $i.CPU = $cpu[$p.Name]
            $i.PM = $p.PrivateMemorySize64
            $i.WS = $p.WorkingSet64
            $i.ParentId = $p.Parent.Id
            $i.Threads = $p.Threads.Count
            $i.Description = $p.Description

            $pi += $i
        }
    }

    $pi
}    

function Get-ProcessExtWmi {
    param (
        [string]$Name = ""
    )

    $CpuCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $pi = @()
    $cpu = @{}
    $desc = @{}

    (get-CimInstance win32_PerfFormattedData_PerfProc_Process ) | ForEach-Object -Process {
        $cpu[$_.IDProcess] = [Decimal]::Round(($_.PercentProcessorTime / $CpuCores), 2)
    }

    Get-Process | ForEach-Object -Process {
        $desc[$_.Id] = $_.Description
    }

    $gp = Get-CimInstance Win32_Process

    foreach ($p in $gp) {

        if ($Name -ne "") {
            if (-not ($p.Caption -match "^$Name$")) {
                continue
            }
        }
        
        $add = $true

        if (-not $cpu.ContainsKey($p.ProcessId)) {
            $cpu[$p.ProcessId] = -1
        }
        if ($add) {
            $i = New-Object -TypeName ProcessInfo
            $i.Id = $p.ProcessId
            $i.Name = $p.Caption
            $i.CPU = $cpu[$p.ProcessId]
            $i.PM = $p.PrivateMemorySize64
            $i.WS = $p.WS
            $i.ParentId = $p.ParentProcessId
            $i.Threads = $p.ThreadCount
            $i.Description = $desc[[int]$p.ProcessId]

            $pi += $i
        }
    }

    $pi
}    

function Get-KeyCommand {
    param (
        [object]$KeyMap,
        [System.ConsoleKeyInfo]$key
    ) 

    if ($KeyMappings.ContainsKey($key.Modifiers)) {
        return $KeyMappings[$key.Modifiers][$key.Key]
    }

    return $KeyMappings["None"][$key.Key]
}

function Show-ProcessExt {
    param (
        [string]$Name = "",
        [float]$MinCpu = 0.001,
        [SortProperty]$SortProperty = [SortProperty]::CPU,
        [SortDirection]$SortDirection = [SortDirection]::Descending,
        [switch]$HideHeader,
        [switch]$Continuous,
        [int]$Delay = 2
    )


    $KeyMappings = @{
        "None"                                                                                                   = @{
            [ConsoleKey]::Q   = [KeyCommand]::Quit
            [ConsoleKey]::F10 = [KeyCommand]::Quit
        }
        [System.ConsoleModifiers]::Control                                                                       = @{
            # [ConsoleKey]::C = [KeyCommand]::Quit
            [ConsoleKey]::P = [KeyCommand]::SortCpu
            [ConsoleKey]::N = [KeyCommand]::SortName
            [ConsoleKey]::W = [KeyCommand]::SortMemory
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
        $ps = Get-ProcessExtWmi -Name $Name
    
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
            Write-Wansi ("{0}{1}{2} {3}{4}{5}{6}`n" -f
                (ConvertTo-AnsiString "{:F15:}{:B6:}Id" -PadRight 8).Value,
                (ConvertTo-AnsiString "ParentId" -PadRight 8).Value,
                (ConvertTo-AnsiString "CPU%" -PadLeft 8).Value,
                (ConvertTo-AnsiString "WS" -PadLeft 8).Value,
                (ConvertTo-AnsiString "Thd" -PadLeft 5).Value,
                (ConvertTo-AnsiString " Name" -PadRight 30).Value,
                (ConvertTo-AnsiString " Description{:EraseLine:}" -PadRight 30).Value,
                (ConvertTo-AnsiString "{:R:}").Value

            )        
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

                        if ($linesDisplayed -ge $maxProcesses) {
                            break
                        }

                        Write-Wansi ("{0}{1}{2} {3}{4}{5}{6}`n" -f
                            (ConvertTo-AnsiString "{:R:}{:F15:}$($p.Id){:R:}" -PadRight 8).Value,
                            (ConvertTo-AnsiString "{:F15:}$($p.ParentId){:R:}" -PadRight 8).Value,
                            (ConvertTo-AnsiString "{:F10:}$($p.CPU){:R:}" -PadLeft 8).Value,
                            (ConvertTo-AnsiString "{:F166:}$([int64]($p.WS / 1024)){:R:}" -PadLeft 8).Value,
                            (ConvertTo-AnsiString "{:F32:}$([int64]($p.Threads)){:R:}" -PadLeft 5).Value,
                            (ConvertTo-AnsiString "{:F3:} $($p.Name){:R:}" -PadRight 30).Value,
                            (ConvertTo-AnsiString "{:F8:} $($p.Description){:R:}{:EraseLine:}" -PadRight 40).Value.SubString(0, 40)
                        )
                    }
                }
            }
        }

        if ($Continuous) {
            $linesToClear = $host.Ui.RawUI.WindowSize.Height - $linesDisplayed - 2

            while ($linesToClear -gt 0) {
                Write-Wansi "{:EraseLine:}`n"                    
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

                $kc = Get-KeyCommand $KeyMappings $keyHit

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

    Get-ProcessExtWmi "$wordToComplete*" | Sort-Object -Property Name | ForEach-Object -Process { if ($_.Name.ToUpper().StartsWith($wordToComplete.ToUpper())) { "'$($_.Name)'" } }
}

Register-ArgumentCompleter -CommandName Get-ProcessExt -ParameterName Name -ScriptBlock $processCompleter
Register-ArgumentCompleter -CommandName Show-ProcessExt -ParameterName Name -ScriptBlock $processCompleter

Export-ModuleMember -Function Out-Default, 'Get-ProcessExt'
Export-ModuleMember -Function Out-Default, 'Get-ProcessExtWmi'
Export-ModuleMember -Function Out-Default, 'Show-ProcessExt'

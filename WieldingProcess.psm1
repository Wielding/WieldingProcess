Import-Module WieldingAnsi

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

enum SortProperty {
    None
    CPU
    Name
}

enum SortDirection {
    Ascending
    Descending
}

function Show-ProcessExt {
    param (
        [string]$Name = "*",
        [float]$MinCpu = 0.01,
        [SortProperty]$SortProperty = [SortProperty]::None,
        [SortDirection]$SortDirection = [SortDirection]::Ascending,
        [switch]$HideHeader,
        [switch]$Continuous
    )

    $quitKeys = @([int][char]'Q', [int][char]'q', 3)

    if ($Continuous) {
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "EraseDisplay" -Value "`e[2J" -Force
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "MoveHome" -Value "`e[0;0H" -Force
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "EraseLine" -Value "`e[K" -Force
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "HideCursor" -Value "`e[?25l" -Force
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "ShowCursor" -Value "`e[?25h" -Force
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "EnableAlt" -Value "`e[?1049h" -Force
        Add-Member -InputObject $Wansi -MemberType NoteProperty -Name "DisableAlt" -Value "`e[?1049l" -Force
    }

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
            Write-Wansi ("{0}{1} {2}{3}{4}`n" -f
                (ConvertTo-AnsiString "{:F15:}{:B6:}Id" -PadRight 10).Value,
                (ConvertTo-AnsiString "CPU%" -PadLeft 8).Value,
                (ConvertTo-AnsiString "Name" -PadRight 30).Value,
                (ConvertTo-AnsiString "Description{:EraseLine:}" -PadRight 40).Value,
                (ConvertTo-AnsiString "{:R:}").Value

            )        
        }

        $maxProcesses = $Host.UI.RawUI.WindowSize.Height - 1

        foreach ($p in $ps) {
            if ($p.Id -ne 0) {
                if ($p.CPU -ge $MinCpu) {
                    if ($null -eq $p.ParentId) {
                        $linesDisplayed++                        

                        if ($linesDisplayed -ge $maxProcesses) {
                            break
                        }

                        Write-Wansi ("{0}{1} {2}{3}`n" -f
                            (ConvertTo-AnsiString "{:F15:}$($p.Id){:R:}" -PadRight 10).Value,
                            (ConvertTo-AnsiString "{:F10:}$($p.CPU){:R:}" -PadLeft 8).Value,
                            (ConvertTo-AnsiString "{:F3:}$($p.Name){:R:}" -PadRight 30).Value,
                            (ConvertTo-AnsiString "{:F8:}$($p.Description){:R:}{:EraseLine:}" -PadRight 40).Value.SubString(0, 40 + $Wansi.EraseLine.Length)
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

            $moveToLastLine = "`e[$($host.Ui.RawUI.WindowSize.Height);0H"
            Write-Wansi "$moveToLastLine{:F15:}{:B6:}'Q' or 'Ctrl-C' to quit{:EraseLine:}{:R:}"
        }

        if ($Host.UI.RawUI.KeyAvailable) { 
            $keyHit = $Host.UI.RawUI.ReadKey("AllowCtrlC,IncludeKeyUp,NoEcho")
            if ($quitKeys.Contains($keyHit.VirtualKeyCode)) {
                Write-Wansi "{:DisableAlt:}{:ShowCursor:}"
                return
            }
        }
    }
}


$processCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-Process "$wordToComplete*" | Sort-Object -Property Name | ForEach-Object -Process { if ($_.Name.ToUpper().StartsWith($wordToComplete.ToUpper())) { "'$($_.Name)'" } }
}

Register-ArgumentCompleter -CommandName Get-ProcessExt -ParameterName Name -ScriptBlock $processCompleter
Register-ArgumentCompleter -CommandName Show-ProcessExt -ParameterName Name -ScriptBlock $processCompleter

Export-ModuleMember -Function Out-Default, 'Get-ProcessExt'
Export-ModuleMember -Function Out-Default, 'Show-ProcessExt'

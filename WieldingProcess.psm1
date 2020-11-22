Import-Module WieldingAnsi

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
        [switch]$HideHeader
    )

    $ps = Get-ProcessExt -Name $Name
    
    if ($SortProperty -ne [SortProperty]::None) {
        if ($SortDirection -eq [SortDirection]::Descending) {
            $ps = $ps | Sort-Object -Property "$SortProperty" -Descending
        }
        else {
            $ps = $ps | Sort-Object -Property "$Sort"
        }
    }

    if (-not $HideHeader) {
        Write-Wansi ("{0}{1}{2}{3}`n" -f
            (ConvertTo-AnsiString "{:F15:}{:UnderlineOn:}Id{:R:}" -PadRight 10).Value,
            (ConvertTo-AnsiString "{:F15:}{:UnderlineOn:}CPU{:R:}" -PadRight 8).Value,
            (ConvertTo-AnsiString "{:F15:}{:UnderlineOn:}Name{:R:}" -PadRight 30).Value,
            (ConvertTo-AnsiString "{:F15:}{:UnderlineOn:}Description{:R:}" -PadRight 40).Value
        )        
    }

    foreach ($p in $ps) {
        if ($p.Id -ne 0) {
            if ($p.CPU -ge $MinCpu) {
                if ($null -eq $p.ParentId) {
                    Write-Wansi ("{0}{1}{2}{3}`n" -f
                        (ConvertTo-AnsiString "{:F15:}$($p.Id){:R:}" -PadRight 10).Value,
                        (ConvertTo-AnsiString "{:F10:}$($p.CPU){:R:}" -PadRight 8).Value,
                        (ConvertTo-AnsiString "{:F3:}$($p.Name){:R:}" -PadRight 30).Value,
                        (ConvertTo-AnsiString "{:F8:}$($p.Description){:R:}" -PadRight 40).Value.SubString(0, 40)
                    )
                }
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

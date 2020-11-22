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

    $wmi = Get-CimInstance -Class Win32_Process

    (Get-Counter "\Process($Name)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples  | ForEach-Object -Process {
        $cpu[$_.InstanceName] = [Decimal]::Round(($_.CookedValue / $CpuCores), 2)
    }

    $gp = Get-Process -Name $Name

    foreach ($p in $gp) {
        $add = $true

        if (-not $cpu.ContainsKey($p.Name))
        {
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

function Show-ProcessExt {
    param (
        [string]$Name
    )

    Get-ProcessExt -Name $Name
}


$processCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-Process "$wordToComplete*" | Sort-Object -Property Name | ForEach-Object -Process { if ($_.Name.ToUpper().StartsWith($wordToComplete.ToUpper())) { "'$($_.Name)'" } }
}

Register-ArgumentCompleter -CommandName Get-ProcessExt -ParameterName Name -ScriptBlock $processCompleter
Register-ArgumentCompleter -CommandName Show-ProcessExt -ParameterName Name -ScriptBlock $processCompleter

Export-ModuleMember -Function Out-Default, 'Get-ProcessExt'
Export-ModuleMember -Function Out-Default, 'Show-ProcessExt'
# Export-ModuleMember -Variable 'GdcTheme'
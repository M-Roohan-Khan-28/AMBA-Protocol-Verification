param(
    [string]$OutputDir = '',
    [string]$SourceRoot = '',
    [string]$InventoryPath = '',
    [string]$ModelSimBin = 'C:\intelFPGA\20.1\modelsim_ase\win32aloem'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $OutputDir) {
    $OutputDir = Join-Path $root ("build\test-runs\portfolio-{0}-{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N').Substring(0,8))
}
$out = [IO.Path]::GetFullPath($OutputDir)
if (Test-Path -LiteralPath $out) { throw "Output directory already exists: $out" }
New-Item -ItemType Directory -Path $out | Out-Null
if (-not $InventoryPath) { $InventoryPath = Join-Path $PSScriptRoot 'portfolio_suites.json' }
$inventory = Get-Content -LiteralPath $InventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($inventory.Count -eq 0) { throw 'Suite inventory is empty' }
$names = @($inventory | ForEach-Object { $_.name })
if (($names | Select-Object -Unique).Count -ne $names.Count) { throw 'Duplicate suite names' }

$simulator = $null
$toolsAvailable = $true
foreach ($tool in @('vlib.exe', 'vlog.exe', 'vsim.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModelSimBin $tool))) { $toolsAvailable = $false }
}
if ($toolsAvailable) {
    $simulator = (& (Join-Path $ModelSimBin 'vsim.exe') -version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $toolsAvailable = $false }
}
$gitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)
$results = @()

function Test-SimulationLog {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing simulation log: $Path" }
    $log = Get-Content -LiteralPath $Path -Raw
    if ($log -match '(?im)^\s*#?\s*\*\*\s+(Error|Fatal):|TOTAL FAILED\s*=\s*[1-9]|^# Errors:\s*[1-9]') {
        throw "Simulator error or failed check: $Path"
    }
    if ($log -notmatch '\$finish') { throw "Missing finish marker: $Path" }
    if ($log -notmatch '(?m)^# Errors: 0, Warnings: 0') { throw "Missing zero-error simulator summary: $Path" }
    return $log
}

foreach ($suite in $inventory) {
    $suiteDir = Join-Path $out $suite.name
    New-Item -ItemType Directory -Path $suiteDir | Out-Null
    $result = [ordered]@{
        name = $suite.name
        repository = $suite.repository
        repository_url = "https://github.com/M-Roohan-Khan-28/$($suite.repository)"
        required = [bool]$suite.required
        status = 'NOT RUN'
        reason = ''
        source_revision = $null
        command = $null
        simulator_version = $simulator
        seed = $suite.seed
        count_kind = $suite.count_kind
        count = $null
        exit_code = $null
        elapsed_seconds = $null
        log_path = $null
        timeout_seconds = $suite.timeout_seconds
    }
    if (-not $suite.enabled) {
        $result.reason = $suite.reason
        $results += [pscustomobject]$result
        continue
    }
    if (-not $gitAvailable) {
        $result.status = 'BLOCKED'; $result.reason = 'git executable is missing'
        $results += [pscustomobject]$result
        continue
    }
    if (-not $toolsAvailable) {
        $result.status = 'BLOCKED'; $result.reason = "Required ModelSim tools missing or unusable in $ModelSimBin"
        $results += [pscustomobject]$result
        continue
    }
    $work = Join-Path $suiteDir 'source'
    $source = if ($SourceRoot) { Join-Path $SourceRoot $suite.repository } else { $result.repository_url + '.git' }
    try {
        & git clone --quiet --branch main --no-hardlinks $source $work 2>&1 | Out-File -FilePath (Join-Path $suiteDir 'clone.log')
        if ($LASTEXITCODE -ne 0) { throw "git clone exited $LASTEXITCODE" }
        $result.source_revision = (& git -C $work rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read source revision' }
    } catch {
        $result.status = 'BLOCKED'; $result.reason = "Source clone failed: $($_.Exception.Message)"
        $results += [pscustomobject]$result
        continue
    }
    $script = Join-Path $work $suite.script
    if (-not (Test-Path -LiteralPath $script)) {
        $result.status = 'BLOCKED'; $result.reason = "Missing runner: $($suite.script)"
        $results += [pscustomobject]$result
        continue
    }
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
    if ($suite.mode -in @('portable', 'axi', 'dma')) {
        $arguments += " -OutputDir `"$(Join-Path $suiteDir 'output')`""
    }
    $result.command = "powershell.exe $arguments"
    $result.log_path = Join-Path $suiteDir 'console.log'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['PATH'] = "$ModelSimBin;$($psi.EnvironmentVariables['PATH'])"
    $psi.EnvironmentVariables['MODELSIM_BIN'] = $ModelSimBin
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $proc = $null
    try {
        $proc = [Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $finished = $proc.WaitForExit([int]$suite.timeout_seconds * 1000)
        if (-not $finished) { $proc.Kill(); $proc.WaitForExit() }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $suiteDir 'console.log'), $stdout)
        [IO.File]::WriteAllText((Join-Path $suiteDir 'stderr.log'), $stderr)
        $result.exit_code = $proc.ExitCode
        if (-not $finished) { throw "Timed out after $($suite.timeout_seconds) seconds" }
        if ($proc.ExitCode -ne 0) { throw "Runner exited $($proc.ExitCode)" }
        switch ($suite.mode) {
            'portable' {
                $primary = Test-SimulationLog (Join-Path $suiteDir 'output\simulation.log')
            }
            'legacy' {
                $primary = Test-SimulationLog (Join-Path $work 'reports\simulation.log')
                if ($primary -notmatch 'TOTAL FAILED\s*=\s*0') { throw 'Missing zero-failed check summary' }
            }
            'axi' {
                $primary = $stdout
                $simLogs = @(Get-ChildItem -LiteralPath (Join-Path $suiteDir 'output') -Filter 'simulation.log' -Recurse -File)
                if ($simLogs.Count -ne [int]$suite.expected_count) { throw "Expected $($suite.expected_count) AXI simulation logs; found $($simLogs.Count)" }
                foreach ($log in $simLogs) { $null = Test-SimulationLog $log.FullName }
            }
            'dma' {
                $primary = Test-SimulationLog (Join-Path $suiteDir 'output\simulation.log')
                $dmaResultPath = Join-Path $suiteDir 'output\result.json'
                if (-not (Test-Path -LiteralPath $dmaResultPath)) { throw 'Missing DMA result JSON' }
                $dmaResult = Get-Content -LiteralPath $dmaResultPath -Raw | ConvertFrom-Json
                if ($dmaResult.status -ne 'PASS' -or $dmaResult.dirty_source -or
                    $dmaResult.simulator_exit_code -ne 0 -or $dmaResult.wrapper_exit_code -ne 0 -or
                    $dmaResult.checks -ne 824446 -or $dmaResult.cases -ne 25 -or
                    $dmaResult.source_revision -ne $result.source_revision) {
                    throw 'DMA result JSON disagrees with clean source or expected results'
                }
            }
            'soc' {
                $primary = Get-Content -LiteralPath (Join-Path $work 'logs\regression_summary.log') -Raw
                $completed = @([regex]::Matches($primary, '(?m)^PASS (?!REGRESSION)(\S+)'))
                if ($completed.Count -ne [int]$suite.expected_count) { throw "Expected $($suite.expected_count) SoC run entries; found $($completed.Count)" }
                foreach ($entry in $completed) {
                    $testLog = Join-Path $work ("logs\{0}.log" -f $entry.Groups[1].Value)
                    $null = Test-SimulationLog $testLog
                }
            }
            default { throw "Unknown suite mode: $($suite.mode)" }
        }
        $match = [regex]::Match($primary, $suite.pass_regex)
        if (-not $match.Success) { throw 'Expected result marker missing' }
        $count = [int]$match.Groups[1].Value
        if ($count -ne [int]$suite.expected_count) { throw "Expected $($suite.expected_count) $($suite.count_kind); observed $count" }
        if ($suite.mode -eq 'soc' -and [int]$match.Groups[2].Value -ne $count) { throw 'SoC denominator differs from observed runs' }
        $result.count = $count
        $result.status = 'PASS'
    } catch {
        $result.status = 'FAIL'
        $result.reason = $_.Exception.Message
    } finally {
        $timer.Stop()
        $result.elapsed_seconds = [math]::Round($timer.Elapsed.TotalSeconds, 2)
        if ($proc) { $proc.Dispose() }
    }
    $results += [pscustomobject]$result
    Write-Output ("{0} {1} revision={2} count={3} exit={4} seconds={5} {6}" -f
        $result.status, $result.name, $result.source_revision, $result.count,
        $result.exit_code, $result.elapsed_seconds, $result.reason)
}

$aggregateExit = 0
if (@($results | Where-Object { $_.required -and $_.status -ne 'PASS' }).Count -gt 0) { $aggregateExit = 1 }
$summary = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    inventory = [IO.Path]::GetFullPath($InventoryPath)
    source_root = $SourceRoot
    simulator_version = $simulator
    aggregate_exit_code = $aggregateExit
    results = $results
}
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $out 'results.json') -Encoding UTF8
$md = @('# Portfolio regression', '', "Simulator: $simulator", '', '| Suite | Required | Status | Revision | Count | Exit | Seconds | Reason |', '| --- | --- | --- | --- | ---: | ---: | ---: | --- |')
foreach ($r in $results) {
    $md += "| $($r.name) | $($r.required) | $($r.status) | $($r.source_revision) | $($r.count) $($r.count_kind) | $($r.exit_code) | $($r.elapsed_seconds) | $($r.reason) |"
}
$md += ''; $md += "Aggregate exit code: $aggregateExit"
$md | Set-Content -LiteralPath (Join-Path $out 'SUMMARY.md') -Encoding UTF8
Write-Output "AGGREGATE_EXIT=$aggregateExit results=$out"
exit $aggregateExit

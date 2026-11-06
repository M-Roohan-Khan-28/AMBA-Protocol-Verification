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
foreach ($suite in $inventory) {
    if ($suite.revision -notmatch '^[0-9a-f]{40}$') { throw "Missing full SHA lock: $($suite.name)" }
}

$runnerRevision = $null
$runnerScriptRevision = $null
$inventoryRevision = $null
$runnerDirty = $true
if (Get-Command git -ErrorAction SilentlyContinue) {
    $runnerRevision = (& git -C $root rev-parse HEAD 2>$null | Out-String).Trim()
    if ($runnerRevision -notmatch '^[0-9a-f]{40}$') { $runnerRevision = $null }
    $runnerScriptRevision = (& git -C $root log -1 --format=%H -- scripts/run_portfolio_regression.ps1 2>$null | Out-String).Trim()
    $inventoryRevision = (& git -C $root log -1 --format=%H -- scripts/portfolio_suites.json 2>$null | Out-String).Trim()
    $runnerDirty = [bool](@(git -C $root status --porcelain).Count)
}
$runnerScriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$inventorySha256 = (Get-FileHash -LiteralPath $InventoryPath -Algorithm SHA256).Hash

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
        expected_revision = $suite.revision
        revision_match = $false
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
        & git -c core.longpaths=true clone --quiet --no-hardlinks $source $work 2>&1 | Out-File -FilePath (Join-Path $suiteDir 'clone.log')
        if ($LASTEXITCODE -ne 0) { throw "git clone exited $LASTEXITCODE" }
        # The clone-time -c setting is not saved in the new repository. Keep
        # it for the detached checkout, which may remove long evidence paths.
        & git -C $work config core.longpaths true
        if ($LASTEXITCODE -ne 0) { throw 'Cannot enable long Git paths in source clone' }
        & git -C $work checkout --quiet --detach $suite.revision 2>&1 | Out-File -FilePath (Join-Path $suiteDir 'checkout.log')
        if ($LASTEXITCODE -ne 0) { throw "Locked checkout failed: $($suite.revision)" }
        $result.source_revision = (& git -C $work rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read source revision' }
        $result.revision_match = ($result.source_revision -eq $suite.revision)
        if (-not $result.revision_match) {
            throw "Revision mismatch expected=$($suite.revision) observed=$($result.source_revision)"
        }
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
    if ($suite.mode -in @('portable', 'axi', 'dma', 'amba', 'coherent')) {
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
                    $dmaResult.checks -ne 925460 -or $dmaResult.cases -ne 27 -or
                    $dmaResult.source_revision -ne $result.source_revision) {
                    throw 'DMA result JSON disagrees with clean source or expected results'
                }
            }
            'amba' {
                $ambaPath = Join-Path $suiteDir 'output\results.json'
                if (-not (Test-Path -LiteralPath $ambaPath)) { throw 'Missing AMBA results JSON' }
                $amba = Get-Content -LiteralPath $ambaPath -Raw | ConvertFrom-Json
                if ($amba.aggregate_exit_code -ne 0 -or $amba.dirty_source -or
                    $amba.source_revision -ne $result.source_revision -or
                    @($amba.results).Count -ne [int]$suite.expected_count -or
                    @($amba.results | Where-Object status -ne 'PASS').Count -ne 0) {
                    throw 'AMBA results JSON reports failed, missing, or dirty source'
                }
                foreach ($entry in $amba.results) {
                    if ($entry.simulator_exit_code -ne 0) { throw "AMBA simulator exit: $($entry.name)" }
                    $log = Test-SimulationLog $entry.simulation_log
                    if ($log -notmatch 'AMBA_\w+_PASS|DMA_REGRESSION_PASS') {
                        throw "AMBA result marker missing: $($entry.name)"
                    }
                }
                $primary = "AMBA_REGRESSION_PASS suites=$(@($amba.results).Count)"
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
            'coherent' {
                $primary = Test-SimulationLog (Join-Path $suiteDir 'output\simulation.log')
                $null = Test-SimulationLog (Join-Path $suiteDir 'output\program.log')
                $resultPath = Join-Path $suiteDir 'output\results.json'
                if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Missing coherent result JSON' }
                $coherent = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
                if ($coherent.status -ne 'PASS' -or $coherent.source_revision -ne $result.source_revision -or
                    $coherent.compile_exit -ne 0 -or $coherent.simulation_exit -ne 0 -or
                    $coherent.cases -ne 71 -or $coherent.checks -ne 1477 -or
                    $coherent.accepted -ne 82 -or $coherent.completed -ne 81 -or
                    $coherent.aborted -ne 1 -or $coherent.contention_waits -ne 26 -or
                    $coherent.program_simulation_exit -ne 0 -or $coherent.program_checks -ne 135 -or
                    $coherent.program_accepted -ne 6 -or $coherent.program_completed -ne 6 -or
                    $coherent.concurrent_simulation_exit -ne 0 -or $coherent.concurrent_checks -ne 106 -or
                    $coherent.concurrent_simultaneous -lt 1 -or $coherent.concurrent_busy_waits -lt 2) {
                    throw 'Coherent result JSON disagrees with tested source or required counts'
                }
                $null = Test-SimulationLog (Join-Path $suiteDir 'output\concurrent.log')
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
if (-not $runnerRevision -or $runnerDirty -or
    $runnerScriptRevision -notmatch '^[0-9a-f]{40}$' -or
    $inventoryRevision -notmatch '^[0-9a-f]{40}$') { $aggregateExit = 1 }
$summary = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    inventory = [IO.Path]::GetFullPath($InventoryPath)
    source_root = $SourceRoot
    simulator_version = $simulator
    runner_revision = $runnerRevision
    runner_script_revision = $runnerScriptRevision
    inventory_revision = $inventoryRevision
    runner_script_sha256 = $runnerScriptSha256
    inventory_sha256 = $inventorySha256
    runner_dirty = $runnerDirty
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

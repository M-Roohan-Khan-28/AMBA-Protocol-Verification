param(
    [string]$OutputDir = 'amba-output',
    [string]$SourceRoot = '',
    [string]$ModelSimBin = 'C:\intelFPGA\20.1\modelsim_ase\win32aloem'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$out = if ([IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $repo $OutputDir }
if (Test-Path -LiteralPath $out) { throw "Output directory already exists: $out" }
New-Item -ItemType Directory -Path $out | Out-Null
$env:PATH = "$ModelSimBin;$env:PATH"
$revision = (& git -C $repo rev-parse HEAD 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-f]{40}$') {
    throw 'AMBA source must be committed before a recorded run'
}
$dirty = [bool](@(git -C $repo status --porcelain).Count)
if ($dirty) { throw 'AMBA source is dirty; commit before a recorded run' }
$sources = @(
    @{ name='apb'; repository='APB-Interface-Verification'; pin='e30fd5242a1e84be92107d6be75652220748a8a7' },
    @{ name='ahb'; repository='AHB-Lite-RAM-Interface'; pin='659fba67ce85a01643cceca2c8d1e67ea3903995' },
    @{ name='axil'; repository='AXI4-Lite-Memory-Interface'; pin='faf43379b24a524999eb2c8ad7e100cde35054c3' },
    @{ name='axi4'; repository='AXI4-DMA-Subsystem'; pin='a2d3d57edaa9eb441f3289bf5320f4df2f074144' }
)
$suites = @(
    @{ name='apb-adapter'; source='apb'; top='apb_adapter_test'; marker='AMBA_APB_PASS transfers=256 checks=(\d+) violations=0'; expected=452 },
    @{ name='apb-negative'; source='apb'; top='apb_monitor_negative'; marker='AMBA_APB_NEGATIVE_PASS detected=(\d+)'; expected=1 },
    @{ name='apb-responder'; source='apb'; top='apb_responder_test'; marker='AMBA_APB_RESPONDER_PASS transfers=7 checks=(\d+) waits=\d+'; expected=13 },
    @{ name='ahb-adapter'; source='ahb'; top='ahb_adapter_test'; marker='AMBA_AHB_PASS addresses=67 checks=(\d+) violations=0'; expected=119 },
    @{ name='ahb-negative'; source='ahb'; top='ahb_monitor_negative'; marker='AMBA_AHB_NEGATIVE_PASS detected=(\d+)'; expected=2 },
    @{ name='axil-adapter'; source='axil'; top='axi_lite_adapter_test'; marker='AMBA_AXIL_PASS writes=26 reads=34 checks=(\d+) violations=0'; expected=98 },
    @{ name='axil-negative'; source='axil'; top='axi_lite_monitor_negative'; marker='AMBA_AXIL_NEGATIVE_PASS detected=(\d+)'; expected=2 },
    @{ name='axil-response-negative'; source='axil'; top='axi_lite_response_negative'; marker='AMBA_AXIL_RESPONSE_NEGATIVE_PASS scenarios=(\d+) violations=\d+'; expected=4 },
    @{ name='axi4-adapter'; source='axi4'; top='dma_adapter_test'; marker='DMA_REGRESSION_PASS cases=(\d+) checks=1352655 seed=0x28A6BEEF'; expected=40; extra='AMBA_AXI4_MONITOR_PASS read_bursts=21 write_bursts=21 read_beats=315 write_beats=315' },
    @{ name='axi4-negative'; source='axi4'; top='axi4_monitor_negative'; marker='AMBA_AXI4_NEGATIVE_PASS detected=(\d+)'; expected=1 },
    @{ name='axi4-response-negative'; source='axi4'; top='axi4_response_negative'; marker='AMBA_AXI4_RESPONSE_NEGATIVE_PASS scenarios=(\d+) violations=\d+'; expected=4 }
)
$simulator = $null
$toolsOk = [bool](Get-Command git -ErrorAction SilentlyContinue)
foreach ($name in @('vlib.exe','vlog.exe','vsim.exe')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { $toolsOk = $false }
}
if ($toolsOk) { $simulator = (& vsim -version 2>&1 | Out-String).Trim() }
$sourcePaths = @{}
$sourceErrors = @{}
foreach ($source in $sources) {
    $dest = Join-Path $out ("sources\" + $source.name)
    New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
    if (-not $toolsOk) { $sourceErrors[$source.name] = 'Required Git/ModelSim tool missing'; continue }
    try {
        $url = if ($SourceRoot) { Join-Path $SourceRoot $source.repository } else { "https://github.com/M-Roohan-Khan-28/$($source.repository).git" }
        & git clone --quiet $url $dest 2>&1 | Out-File (Join-Path $out ("clone-$($source.name).log"))
        if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
        & git -C $dest checkout --quiet --detach $source.pin
        if ($LASTEXITCODE -ne 0 -or (& git -C $dest rev-parse HEAD).Trim() -ne $source.pin) {
            throw 'Pinned source revision unavailable'
        }
        $sourcePaths[$source.name] = $dest
    } catch { $sourceErrors[$source.name] = $_.Exception.Message }
}
$results = @()
foreach ($suite in $suites) {
    $dir = Join-Path $out $suite.name
    New-Item -ItemType Directory -Path $dir | Out-Null
    $entry = [ordered]@{
        name=$suite.name; source=$suite.source; source_revision=($sources | Where-Object name -eq $suite.source).pin
        status='NOT RUN'; reason=''; count=$null; simulator_exit_code=$null
        elapsed_seconds=$null; simulation_log=(Join-Path $dir 'simulation.log')
    }
    if ($sourceErrors.ContainsKey($suite.source)) {
        $entry.status='BLOCKED'; $entry.reason=$sourceErrors[$suite.source]
        $results += [pscustomobject]$entry
        Write-Output "BLOCKED $($suite.name) $($entry.reason)"
        continue
    }
    $dut = $sourcePaths[$suite.source]
    $files = @()
    switch ($suite.source) {
        'apb' { $files=@(
            (Join-Path $repo 'checkers/amba_transactions.sv'),
            (Join-Path $dut 'rtl/design.sv'),
            (Join-Path $repo 'checkers/apb_monitor.sv'),
            (Join-Path $repo 'checkers/apb_master_driver.sv'),
            (Join-Path $repo 'checkers/apb_ram_responder.sv')) }
        'ahb' { $files=@(
            (Join-Path $repo 'checkers/amba_transactions.sv'),
            (Join-Path $dut 'rtl/design.sv'),
            (Join-Path $repo 'checkers/ahb_lite_monitor.sv'),
            (Join-Path $repo 'checkers/ahb_lite_master_driver.sv')) }
        'axil' { $files=@(
            (Join-Path $repo 'checkers/amba_transactions.sv'),
            (Join-Path $dut 'rtl/axi/axi_lite_if.sv'),(Join-Path $dut 'rtl/axi/axi_lite_master.sv'),
            (Join-Path $dut 'rtl/axi/axi_lite_slave.sv'),(Join-Path $dut 'rtl/memory/sram.sv'),
            (Join-Path $dut 'rtl/axi4_lite_memory_top.sv'),(Join-Path $repo 'checkers/axi_lite_monitor.sv'),
            (Join-Path $repo 'checkers/axi_lite_request_driver.sv')) }
        'axi4' { $files=@(
            (Join-Path $dut 'rtl/axi4_dma_subsystem.sv'),(Join-Path $dut 'tb/tb_dma_portable.sv'),
            (Join-Path $repo 'checkers/axi4_burst_monitor.sv')) }
    }
    $files += Join-Path $repo ("tb/" + $suite.top + '.sv')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Push-Location $dir
    try {
        & vlib work 2>&1 | Out-File 'library.log'
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
        & vlog -sv @files 2>&1 | Out-File 'compile.log'
        if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName=(Get-Command vsim.exe).Source
        $psi.WorkingDirectory=$dir
        $psi.Arguments="-c -onfinish exit $($suite.top) -do `"run -all; quit -code 0`""
        $psi.UseShellExecute=$false
        $psi.RedirectStandardOutput=$true
        $psi.RedirectStandardError=$true
        $proc=[Diagnostics.Process]::Start($psi)
        $stdoutTask=$proc.StandardOutput.ReadToEndAsync()
        $stderrTask=$proc.StandardError.ReadToEndAsync()
        $finished=$proc.WaitForExit(120000)
        if (-not $finished) { $proc.Kill(); $proc.WaitForExit() }
        $log=$stdoutTask.GetAwaiter().GetResult()+$stderrTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($entry.simulation_log,$log)
        $entry.simulator_exit_code=$proc.ExitCode
        if (-not $finished) { throw 'Simulation timed out after 120 seconds' }
        if ($proc.ExitCode -ne 0 -or $log -match '(?im)^\s*#?\s*\*\*\s+(Error|Fatal):' -or
            $log -notmatch '(?m)^# Errors: 0, Warnings: 0' -or $log -notmatch '\$finish') {
            throw "Simulation error/fatal or exit $($proc.ExitCode)"
        }
        $match=[regex]::Match($log,$suite.marker)
        if (-not $match.Success -or [int]$match.Groups[1].Value -ne $suite.expected) {
            throw 'Expected result count missing or wrong'
        }
        if ($suite.ContainsKey('extra') -and $log -notmatch $suite.extra) {
            throw 'Independent AXI4 monitor result missing'
        }
        $entry.count=[int]$match.Groups[1].Value
        $entry.status='PASS'
    } catch {
        $entry.status='FAIL';$entry.reason=$_.Exception.Message
    } finally {
        Pop-Location
        $timer.Stop()
        $entry.elapsed_seconds=[math]::Round($timer.Elapsed.TotalSeconds,2)
    }
    $results += [pscustomobject]$entry
    Write-Output "$($entry.status) $($suite.name) count=$($entry.count) exit=$($entry.simulator_exit_code) $($entry.reason)"
}
$exitCode = if (@($results | Where-Object status -ne 'PASS').Count -eq 0) {0} else {1}
[ordered]@{
    source_revision=$revision; dirty_source=$dirty; simulator_version=$simulator
    aggregate_exit_code=$exitCode; results=$results
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'results.json') -Encoding UTF8
Write-Output "AMBA_AGGREGATE_EXIT=$exitCode source=$revision"
exit $exitCode

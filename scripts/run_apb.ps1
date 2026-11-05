param(
    [string]$OutputDir = 'apb-output',
    [string]$APBSource = 'https://github.com/M-Roohan-Khan-28/APB-Interface-Verification.git'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$out = if ([IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $repo $OutputDir }
if (Test-Path -LiteralPath $out) { throw "Output directory already exists: $out" }
foreach ($name in @('git','vlib.exe','vlog.exe','vsim.exe')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "Missing tool: $name" }
}
New-Item -ItemType Directory -Path $out | Out-Null
$pin = '118deb0b339b1c7b000198b7133a05367eb61f76'
$dut = Join-Path $out 'dut'
& git clone --quiet --no-hardlinks $APBSource $dut 2>&1 | Out-File (Join-Path $out 'clone.log')
if ($LASTEXITCODE -ne 0) { throw 'APB DUT clone failed' }
& git -C $dut checkout --quiet --detach $pin
if ($LASTEXITCODE -ne 0 -or (& git -C $dut rev-parse HEAD).Trim() -ne $pin) {
    throw 'APB DUT source revision mismatch'
}
$version = (& vsim -version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Simulator version query failed' }
$revision = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-f]{40}$') {
    throw 'AMBA source must be committed before a recorded run'
}
$dirty = [bool](@(git -C $repo status --porcelain).Count)
if ($dirty) { throw 'AMBA source is dirty; commit before a recorded run' }
$results = @()
foreach ($case in @(
    @{ top='apb_adapter_test'; marker='AMBA_APB_PASS transfers=256 checks=(\d+) violations=0'; expected=452 },
    @{ top='apb_monitor_negative'; marker='AMBA_APB_NEGATIVE_PASS detected=(\d+)'; expected=1 }
)) {
    $dir = Join-Path $out $case.top
    New-Item -ItemType Directory -Path $dir | Out-Null
    Push-Location $dir
    try {
        & vlib work 2>&1 | Out-File 'library.log'
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
        & vlog -sv (Join-Path $dut 'rtl/design.sv') (Join-Path $repo 'checkers/apb_monitor.sv') (Join-Path $repo "tb/$($case.top).sv") 2>&1 | Out-File 'compile.log'
        if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = (Get-Command vsim.exe).Source
        $psi.WorkingDirectory = $dir
        $psi.Arguments = "-c -onfinish exit $($case.top) -do `"run -all; quit -code 0`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $proc = [Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $finished = $proc.WaitForExit(60000)
        if (-not $finished) { $proc.Kill(); $proc.WaitForExit() }
        $log = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $dir 'simulation.log'), $log)
        $timer.Stop()
        if (-not $finished) { throw "Simulation timeout: $($case.top)" }
        if ($proc.ExitCode -ne 0 -or $log -match '(?im)^\s*#?\s*\*\*\s+(Error|Fatal):' -or
            $log -notmatch '(?m)^# Errors: 0, Warnings: 0' -or $log -notmatch '\$finish') {
            throw "Simulation failure: $($case.top) exit=$($proc.ExitCode)"
        }
        $match = [regex]::Match($log,$case.marker)
        if (-not $match.Success -or [int]$match.Groups[1].Value -ne $case.expected) {
            throw "Result marker/count mismatch: $($case.top)"
        }
        $results += [pscustomobject]@{
            name=$case.top; status='PASS'; count=[int]$match.Groups[1].Value
            simulator_exit_code=$proc.ExitCode; elapsed_seconds=[math]::Round($timer.Elapsed.TotalSeconds,2)
            simulation_log=(Join-Path $dir 'simulation.log')
        }
        Write-Output "AMBA_SUITE_PASS top=$($case.top) count=$($match.Groups[1].Value)"
    } finally { Pop-Location }
}
[ordered]@{
    status='PASS'; source_revision=$revision; dut_revision=$pin
    simulator_version=$version; suites=$results; wrapper_exit_code=0
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'result.json') -Encoding UTF8
Write-Output "AMBA_APB_REGRESSION_PASS suites=$($results.Count) revision=$revision"

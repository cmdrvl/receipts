<#
.SYNOPSIS
  PowerShell port of run-receipt.sh — sealed CSV receipt, no bash needed.

.PARAMETER Old
  Path to the older CSV.

.PARAMETER New
  Path to the newer CSV.

.PARAMETER Key
  Column to align rows by. Recommended; without it, rows align by position.

.PARAMETER Out
  Output directory for the sealed pack. Must not exist or must be empty.

.PARAMETER Note
  Optional annotation written into the pack manifest.

.EXAMPLE
  .\run-receipt.ps1 nov.csv dec.csv -Key loan_id -Out C:\Temp\receipt -Note "Q4 reconciliation"

.NOTES
  Exit codes:
    0  pack created (NO_REAL_CHANGE or REAL_CHANGE; both are valid receipts)
    2  refusal — see structured envelope on stderr
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Old,
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$New,
    [string]$Key,
    [string]$Out,
    [string]$Note
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Old)) { Write-Error "not found: $Old"; exit 2 }
if (-not (Test-Path $New)) { Write-Error "not found: $New"; exit 2 }

$work = Join-Path $env:TEMP ("receipts-" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    $shapeReport = Join-Path $work "shape.report.json"
    $rvlReport   = Join-Path $work "rvl.report.json"
    $packOut     = Join-Path $work "pack.out"

    # Build the spine flags arrays
    $keyArgs = @()
    if ($Key) { $keyArgs = @("--key", $Key) }

    # --- shape ---
    Write-Host "==> shape"
    $shapeArgs = @($Old, $New) + $keyArgs + @("--json", "--no-witness")
    & shape @shapeArgs > $shapeReport
    if ($LASTEXITCODE -ne 0) {
        Write-Error "shape REFUSAL — structural incompatibility:"
        Get-Content $shapeReport | Write-Error
        exit 2
    }
    $shape = Get-Content $shapeReport | ConvertFrom-Json
    Write-Host "  shape: $($shape.outcome)"

    # --- rvl ---
    Write-Host "==> rvl"
    $rvlArgs = @($Old, $New) + $keyArgs + @("--json", "--no-witness")
    & rvl @rvlArgs > $rvlReport
    $rvlExit = $LASTEXITCODE
    if ($rvlExit -eq 2) {
        Write-Error "rvl REFUSAL:"
        Get-Content $rvlReport | Write-Error
        exit 2
    }
    $rvl = Get-Content $rvlReport | ConvertFrom-Json
    Write-Host "  rvl:   $($rvl.outcome)"
    if ($rvl.outcome -eq "REAL_CHANGE") {
        $cells = $rvl.counts.numeric_cells_changed
        $rows  = $rvl.counts.rows_aligned
        $total = $rvl.metrics.total_change
        Write-Host "  rvl:   $cells cells changed across $rows aligned rows"
        Write-Host "  rvl:   total numeric movement: $total"
    }

    # --- pack seal ---
    Write-Host "==> pack seal"
    $packArgs = @("seal", $shapeReport, $rvlReport, "--no-witness")
    if ($Out)  {
        New-Item -ItemType Directory -Force -Path $Out | Out-Null
        $packArgs += @("--output", $Out)
    }
    if ($Note) { $packArgs += @("--note", $Note) }
    & pack @packArgs > $packOut 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "pack REFUSAL:"
        Get-Content $packOut | Write-Error
        exit 2
    }

    $createdLine = Get-Content $packOut | Where-Object { $_ -like "PACK_CREATED *" } | Select-Object -First 1
    $packId = ($createdLine -split " ")[1]
    $packDir = Get-Content $packOut | Select-Object -Skip 1 -First 1

    Write-Host ""
    Write-Host "  pack_id: $packId"
    Write-Host "  pack:    $packDir"
    Write-Host ""

    # --- pack verify ---
    Write-Host "==> pack verify"
    & pack verify $packDir --no-witness > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "verify FAILED"
        exit 1
    }
    Write-Host "  verify: OK"
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $work
}

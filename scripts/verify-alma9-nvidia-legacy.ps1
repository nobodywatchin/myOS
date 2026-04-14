$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$legacyLayerPath = Join-Path $repoRoot "recipes/layers/alma9/nvidia-legacy.yml"

if (-not (Test-Path $legacyLayerPath)) {
    throw "Missing legacy layer: $legacyLayerPath"
}

$expectedLegacyRecipes = @(
    "recipes/images/server/alma9/full-nvidia-legacy.yml",
    "recipes/images/workstation/gnome/alma9/core-nvidia-legacy.yml",
    "recipes/images/workstation/gnome/alma9/full-nvidia-legacy.yml",
    "recipes/images/workstation/cosmic/alma9/core-nvidia-legacy.yml",
    "recipes/images/workstation/cosmic/alma9/full-nvidia-legacy.yml"
) | ForEach-Object { Join-Path $repoRoot $_ }

foreach ($recipePath in $expectedLegacyRecipes) {
    if (-not (Test-Path $recipePath)) {
        throw "Missing supported Alma 9 NVIDIA legacy recipe: $recipePath"
    }
}

$legacyLayer = Get-Content $legacyLayerPath -Raw

$requiredSnippets = @(
    "RUN dnf -y module reset nvidia-driver",
    "RUN dnf -y module enable nvidia-driver:580",
    "nvidia-driver nvidia-driver-cuda",
    "--exclude='kernel-debug*'",
    "--exclude='kernel-debug-core*'",
    "--exclude='kernel-debug-modules*'",
    "--exclude='kernel-debug-modules-extra*'"
)

foreach ($snippet in $requiredSnippets) {
    if (-not $legacyLayer.Contains($snippet)) {
        throw "Alma 9 legacy layer is missing required snippet: $snippet"
    }
}

if ($legacyLayer -match "nvidia-driver:latest/default" -or $legacyLayer -match "nvidia-driver:latest") {
    throw "Alma 9 legacy layer must not use the floating nvidia-driver:latest stream."
}

$runtime = @("podman", "docker") |
    ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
    Select-Object -First 1

if (-not $runtime) {
    throw "Need either 'podman' or 'docker' to verify the Alma 9 NVIDIA legacy transaction."
}

$containerImage = "quay.io/almalinuxorg/almalinux-bootc:9"
$repoUrl = "https://git.almalinux.org/rpms/almalinux-release-nvidia-driver/raw/branch/a9/almalinux-nvidia.repo"
$driverStream = "580"

$transactions = @(
    [PSCustomObject]@{
        Images = @(
            "core-full-alma9-nvidia-legacy"
        )
        Packages = @(
            "nvidia-driver",
            "nvidia-driver-cuda"
        )
    },
    [PSCustomObject]@{
        Images = @(
            "workstation-core-gnome-alma9-nvidia-legacy",
            "gnome-alma9-nvidia-legacy",
            "workstation-core-cosmic-alma9-nvidia-legacy",
            "cosmic-alma9-nvidia-legacy"
        )
        Packages = @(
            "nvidia-driver",
            "nvidia-driver-cuda",
            "libnvidia-fbc",
            "libnvidia-cfg",
            "nvidia-settings",
            "nvidia-libXNVCtrl"
        )
    }
)

function Invoke-LegacyTransaction {
    param(
        [string[]]$Packages
    )

    $packageList = [string]::Join(" ", $Packages)
    $containerScript = @"
set -euo pipefail
curl -fsSL $repoUrl -o /etc/yum.repos.d/almalinux-nvidia.repo
rpm -q kernel-core
dnf -y module reset nvidia-driver >/dev/null
dnf -y module enable nvidia-driver:$driverStream >/dev/null
dnf -y --assumeno install $packageList 2>&1 || true
"@

    $output = & $runtime.Source run --rm $containerImage bash -lc $containerScript 2>&1
    return ($output | Out-String)
}

function Parse-LegacyResult {
    param(
        [string]$TransactionOutput
    )

    if ($TransactionOutput -match "(?m)^Error:" -or $TransactionOutput -match "(?m)^\s*- package .* conflicts with ") {
        throw "DNF resolution failed:`n$TransactionOutput"
    }

    $kernelLine = [regex]::Match($TransactionOutput, "(?m)^kernel-core-(?<kernel>\S+)$")
    $kernel = if ($kernelLine.Success) { $kernelLine.Groups["kernel"].Value } else { "unknown" }

    $resolvedPackages = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($TransactionOutput -split "`r?`n")) {
        $match = [regex]::Match($line, "^\s*(?<name>\S+)\s+(?<arch>\S+)\s+(?<version>\S+)\s+almalinux-nvidia\s+")
        if ($match.Success) {
            $resolvedPackages.Add(("{0}-{1}" -f $match.Groups["name"].Value, $match.Groups["version"].Value))
        }
    }

    if ($resolvedPackages.Count -eq 0) {
        throw "Did not find any resolved AlmaLinux NVIDIA packages in transaction output.`n$TransactionOutput"
    }

    $resolvedPackages = $resolvedPackages | Sort-Object -Unique
    $prebuiltPackages = $resolvedPackages | Where-Object { $_ -match "^kmod-nvidia-\d+\.\d+\.\d+-" -and $_ -notmatch "dkms" }
    $dkmsPackages = $resolvedPackages | Where-Object { $_ -match "dkms" }

    $prebuilt = if ($prebuiltPackages) { "yes" } else { "no" }
    $dkms = if ($dkmsPackages) { "yes" } else { "no" }
    $ambiguity = if ($prebuilt -eq "yes" -and $dkms -eq "no") { "none" } else { "unexpected provider mix" }

    if ($kernel -eq "unknown" -and $prebuiltPackages) {
        $kernelMatch = [regex]::Match((@($prebuiltPackages)[0]), "^kmod-nvidia-\d+\.\d+\.\d+-(?<kernel>.+)-3:")
        if ($kernelMatch.Success) {
            $kernel = $kernelMatch.Groups["kernel"].Value
        }
    }

    return [PSCustomObject]@{
        Kernel = $kernel
        ResolvedPackages = $resolvedPackages
        Prebuilt = $prebuilt
        Dkms = $dkms
        Ambiguity = $ambiguity
    }
}

$failures = New-Object System.Collections.Generic.List[string]

foreach ($transaction in $transactions) {
    $transactionOutput = Invoke-LegacyTransaction -Packages $transaction.Packages
    $result = Parse-LegacyResult -TransactionOutput $transactionOutput

    foreach ($image in $transaction.Images) {
        Write-Output "IMAGE=$image"
        Write-Output "DISTRO_BASE=alma9"
        Write-Output "ROLE=$(if ($image -like 'core-full-*') { 'server' } else { 'workstation' })"
        Write-Output "TIER=$(if ($image -like 'workstation-core-*') { 'core' } elseif ($image -like 'core-full-*' -or $image -like 'gnome-*' -or $image -like 'cosmic-*') { 'full' } else { 'unknown' })"
        Write-Output "DRIVER_STREAM=$driverStream"
        Write-Output "KERNEL_CORE=$($result.Kernel)"
        Write-Output "PREBUILT_KMODS=$($result.Prebuilt)"
        Write-Output "DKMS=$($result.Dkms)"
        Write-Output ("RESOLVED_PACKAGES={0}" -f ($result.ResolvedPackages -join ", "))
        Write-Output "AMBIGUITY=$($result.Ambiguity)"
        Write-Output ""
    }

    if ($result.Prebuilt -ne "yes") {
        $failures.Add("Expected prebuilt proprietary kmods for $($transaction.Images -join ', '), but none were resolved.")
    }

    if ($result.Dkms -ne "no") {
        $failures.Add("Expected non-DKMS proprietary kmods for $($transaction.Images -join ', '), but DKMS packages were resolved.")
    }
}

if ($failures.Count -gt 0) {
    throw ($failures -join [Environment]::NewLine)
}

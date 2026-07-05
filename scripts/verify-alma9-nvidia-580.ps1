$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$matrixPath = Join-Path $repoRoot "files/base/runtime/usr/share/current/image-matrix.tsv"
$laneLayerPath = Join-Path $repoRoot "recipes/layers/alma9/nvidia-580.yml"
$workstationVaapiLayerPath = Join-Path $repoRoot "recipes/layers/alma9/nvidia-workstation.yml"

if (-not (Test-Path $laneLayerPath)) {
    throw "Missing Alma 9 NVIDIA 580 layer: $laneLayerPath"
}

if (-not (Test-Path $matrixPath)) {
    throw "Missing image matrix manifest: $matrixPath"
}

if (-not (Test-Path $workstationVaapiLayerPath)) {
    throw "Missing Alma 9 NVIDIA workstation VAAPI layer: $workstationVaapiLayerPath"
}

$laneRows = @(
    Import-Csv -Delimiter "`t" -Path $matrixPath | Where-Object {
        $_.platform -eq 'alma9' -and $_.driver -eq 'nvidia-580'
    }
)

if ($laneRows.Count -ne 3) {
    throw "Expected exactly three Alma 9 NVIDIA 580 rows in the image matrix, found $($laneRows.Count)."
}

$expectedRecipes = @(
    $laneRows | Select-Object -ExpandProperty recipe -Unique | ForEach-Object {
        Join-Path $repoRoot $_
    }
)

foreach ($recipePath in $expectedRecipes) {
    if (-not (Test-Path $recipePath)) {
        throw "Missing supported Alma 9 NVIDIA 580 recipe: $recipePath"
    }
}

$laneRowsByImage = @{}
foreach ($row in $laneRows) {
    $laneRowsByImage[$row.image] = $row
}

$serverImages = @(
    $laneRows |
        Where-Object { $_.role -eq 'server' } |
        Select-Object -ExpandProperty image
)

$workstationImages = @(
    $laneRows |
        Where-Object { $_.role -eq 'workstation' } |
        Select-Object -ExpandProperty image
)

if ($serverImages.Count -ne 1 -or $workstationImages.Count -ne 2) {
    throw "Unexpected Alma 9 NVIDIA 580 role split in the image matrix."
}

$laneLayer = Get-Content $laneLayerPath -Raw

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
    if (-not $laneLayer.Contains($snippet)) {
        throw "Alma 9 NVIDIA 580 layer is missing required snippet: $snippet"
    }
}

if ($laneLayer.Contains("libva-nvidia-driver")) {
    throw "Alma 9 NVIDIA 580 lane layer must stay server-safe; libva-nvidia-driver belongs in alma9/nvidia-workstation.yml."
}

$workstationVaapiLayer = Get-Content $workstationVaapiLayerPath -Raw
if (-not $workstationVaapiLayer.Contains("libva-nvidia-driver")) {
    throw "Alma 9 NVIDIA workstation VAAPI layer must install libva-nvidia-driver."
}

foreach ($row in $laneRows) {
    $recipePath = Join-Path $repoRoot $row.recipe
    $recipeText = Get-Content $recipePath -Raw
    $hasWorkstationVaapiLayer = $recipeText.Contains("layers/alma9/nvidia-workstation.yml")

    if ($row.role -eq "workstation") {
        if (-not $hasWorkstationVaapiLayer) {
            throw "Alma 9 NVIDIA workstation recipe $($row.recipe) must include layers/alma9/nvidia-workstation.yml."
        }
    } elseif ($hasWorkstationVaapiLayer) {
        throw "Alma 9 NVIDIA non-workstation recipe $($row.recipe) must not include layers/alma9/nvidia-workstation.yml."
    }
}

if ($laneLayer -match "nvidia-driver:latest/default" -or $laneLayer -match "nvidia-driver:latest") {
    throw "Alma 9 NVIDIA 580 layer must not use the floating nvidia-driver:latest stream."
}

$runtime = @("podman", "docker") |
    ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
    Select-Object -First 1

if (-not $runtime) {
    throw "Need either 'podman' or 'docker' to verify the Alma 9 NVIDIA 580 transaction."
}

$containerImage = "quay.io/almalinuxorg/almalinux-bootc:9"
$repoUrl = "https://git.almalinux.org/rpms/almalinux-release-nvidia-driver/raw/branch/a9/almalinux-nvidia.repo"
$driverStream = "580"

$transactions = @(
    [PSCustomObject]@{
        Images = @($serverImages)
        Packages = @(
            "nvidia-driver",
            "nvidia-driver-cuda"
        )
    },
    [PSCustomObject]@{
        Images = @($workstationImages)
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

function Test-TransientContainerRuntimeFailure {
    param(
        [string]$Output
    )

    $patterns = @(
        "unexpected EOF",
        "happened during read",
        "while reconnecting",
        "TLS handshake timeout",
        "connection reset",
        "connection refused",
        "i/o timeout",
        "net/http",
        "timeout awaiting response headers",
        "temporary failure",
        "temporarily unavailable",
        "service unavailable",
        "blob to file",
        "cdn.*EOF",
        "quay\.io.*EOF"
    )

    foreach ($pattern in $patterns) {
        if ($Output -match $pattern) {
            return $true
        }
    }

    return $false
}

function Invoke-LaneTransaction {
    param(
        [string[]]$Packages,
        [int]$MaxAttempts = 3
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

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $output = & $runtime.Source run --rm $containerImage bash -lc $containerScript 2>&1
        $exitCode = $LASTEXITCODE
        $text = ($output | Out-String)

        if ($exitCode -eq 0) {
            return $text
        }

        if ((Test-TransientContainerRuntimeFailure -Output $text) -and $attempt -lt $MaxAttempts) {
            Write-Warning "Transient container runtime failure while verifying Alma 9 NVIDIA 580 transaction (attempt $attempt/$MaxAttempts). Retrying."
            Start-Sleep -Seconds ([Math]::Min(30, 5 * $attempt))
            continue
        }

        if (Test-TransientContainerRuntimeFailure -Output $text) {
            throw "Container runtime failed after $MaxAttempts attempts while pulling/running $($containerImage):`n$text"
        }

        return $text
    }

    throw "Container runtime failed without producing transaction output."
}

function Parse-LaneResult {
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
    $transactionOutput = Invoke-LaneTransaction -Packages $transaction.Packages
    $result = Parse-LaneResult -TransactionOutput $transactionOutput

    foreach ($image in $transaction.Images) {
        $row = $laneRowsByImage[$image]
        Write-Output "IMAGE=$image"
        Write-Output "PLATFORM=$($row.platform)"
        Write-Output "ROLE=$($row.role)"
        Write-Output "ENVIRONMENT=$($row.environment)"
        Write-Output "DRIVER=$($row.driver)"
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

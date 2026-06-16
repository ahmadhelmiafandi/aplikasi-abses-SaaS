$ErrorActionPreference = "Stop"
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.1-stable.zip"
$zipFile = "D:\flutter_windows_3.44.1-stable.zip"
$extractPath = "D:\"

# Clean up any partial download
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force
}

Write-Host "1. Downloading Flutter SDK (approx. 900MB)..."
try {
    # Using Start-BitsTransfer which is much faster than Invoke-WebRequest
    Write-Host "Using BITS Transfer to download..."
    Start-BitsTransfer -Source $url -Destination $zipFile -Priority High
    Write-Host "Download complete!"
} catch {
    Write-Host "BITS transfer failed. Trying curl..."
    try {
        & curl.exe -L -o $zipFile $url
        Write-Host "Download complete via curl!"
    } catch {
        Write-Host "curl failed. Trying Invoke-WebRequest..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing
            Write-Host "Download complete via Invoke-WebRequest!"
        } catch {
            Write-Host "Failed to download Flutter: $_"
            exit 1
        }
    }
}

Write-Host "2. Extracting Flutter SDK to D:\..."
try {
    if (Test-Path "D:\flutter") {
        Write-Host "Found existing D:\flutter directory, removing..."
        Remove-Item -Path "D:\flutter" -Recurse -Force
    }
    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
    Write-Host "Extraction complete!"
} catch {
    Write-Host "Failed to extract Flutter: $_"
    exit 1
}

Write-Host "3. Adding D:\flutter\bin to User Environment Path..."
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*D:\flutter\bin*") {
        $newUserPath = $userPath + ";D:\flutter\bin"
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        $env:Path = $env:Path + ";D:\flutter\bin"
        Write-Host "Environment Path updated successfully!"
    } else {
        Write-Host "Environment Path already registered!"
    }
} catch {
    Write-Host "Failed to update Path variable: $_"
}

Write-Host "4. Cleaning up temporary files..."
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force
    Write-Host "Temporary ZIP removed."
}

Write-Host "============================================="
Write-Host "Flutter SDK has been successfully installed!"
Write-Host "Please close and reopen your terminal or IDE."
Write-Host "============================================="

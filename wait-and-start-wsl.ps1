# wait-and-start-wsl.ps1
$VHDXPath = "I:\WSL\Ubuntu\ext4.vhdx"
$UbuntuDistroName = "Ubuntu"

Write-Host "Waiting for I: drive to become available..."

while (-not (Test-Path $VHDXPath)) {
    Start-Sleep -Seconds 2
}

Write-Host "I: is ready. Starting WSL..."
wsl -d $UbuntuDistroName

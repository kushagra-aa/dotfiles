# File: start-docker.ps1
Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for the helper service and engine to be up
Write-Host "Waiting for Docker to become available..."

$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    try {
        docker info > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Docker is ready!"
            break
        }
    } catch {}
    Start-Sleep -Seconds 2
    $elapsed += 2
}
if ($elapsed -ge $timeout) {
    Write-Host "❌ Docker failed to start in time"
}


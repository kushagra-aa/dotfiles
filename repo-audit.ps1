param(
    [Parameter(Mandatory=$true)]
    [string]$BasePath,

    [string[]]$IgnoreDirs = @("node_modules", "dist", ".next", ".git", "build", "out", ".pnpm-store", ".vscode-test"),

    [switch]$OnlyDirty,
    [switch]$OnlyNoRemote,
    [switch]$Summary,
    [switch]$TopLevelOnly,

    [int]$ThrottleLimit = 8
)

# -----------------------------
# Helpers
# -----------------------------

function Is-Ignored($path) {
    foreach ($ignore in $IgnoreDirs) {
        if ($path -match "\\$ignore(\\|$)") {
            return $true
        }
    }
    return $false
}

function Is-ProjectFolder($path) {
    return (
        (Test-Path (Join-Path $path ".git")) -or
        (Test-Path (Join-Path $path "package.json")) -or
        (Test-Path (Join-Path $path "pyproject.toml")) -or
        (Test-Path (Join-Path $path "*.sln"))
    )
}

function Get-GitInfo($repoPath) {
    try {
        Push-Location $repoPath

        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if (-not $branch) { return $null }

        $statusLines = git status --porcelain
        $statusShort = git status -sb 2>$null
        $remotes = git remote

        $hasChanges = $statusLines.Length -gt 0
        $untracked = ($statusLines | Where-Object { $_ -match "^\?\?" }).Count
        $hasRemote = $remotes.Length -gt 0

        $ahead = 0
        $behind = 0

        if ($statusShort -match "ahead (\d+)") {
            $ahead = [int]$Matches[1]
        }
        if ($statusShort -match "behind (\d+)") {
            $behind = [int]$Matches[1]
        }

        $syncStatus = if (-not $hasRemote) {
            "No Remote"
        }
        elseif ($ahead -gt 0) {
            "Ahead ($ahead)"
        }
        elseif ($behind -gt 0) {
            "Behind ($behind)"
        }
        else {
            "Up-to-date"
        }

        return [PSCustomObject]@{
            Path       = $repoPath
            Branch     = $branch
            Status     = if ($hasChanges) { "Dirty" } else { "Clean" }
            Untracked  = $untracked
            Remote     = if ($hasRemote) { "Yes" } else { "No" }
            Sync       = $syncStatus
            Ahead      = $ahead
        }
    }
    catch {
        return $null
    }
    finally {
        Pop-Location
    }
}

# -----------------------------
# Scan Folders
# -----------------------------

Write-Host "`n🔍 Scanning: $BasePath`n" -ForegroundColor Cyan

if ($TopLevelOnly) {
    $folders = Get-ChildItem -Path $BasePath -Directory
} else {
    $folders = Get-ChildItem -Path $BasePath -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not (Is-Ignored $_.FullName) }
}

$projectFolders = $folders | Where-Object { Is-ProjectFolder $_.FullName }

# -----------------------------
# Process (Parallel if PS7)
# -----------------------------

$gitRepos = @()
$nonGit = @()

if ($PSVersionTable.PSVersion.Major -ge 7) {

    $results = $projectFolders | ForEach-Object -Parallel {
        param($using:IgnoreDirs)

        function HasGit($p) {
            Test-Path (Join-Path $p ".git")
        }

        if (HasGit $_.FullName) {
            Push-Location $_.FullName
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            if (-not $branch) { Pop-Location; return }

            $statusLines = git status --porcelain
            $statusShort = git status -sb 2>$null
            $remotes = git remote

            $hasChanges = $statusLines.Length -gt 0
            $untracked = ($statusLines | Where-Object { $_ -match "^\?\?" }).Count
            $hasRemote = $remotes.Length -gt 0

            $ahead = 0
            $behind = 0

            if ($statusShort -match "ahead (\d+)") {
                $ahead = [int]$Matches[1]
            }
            if ($statusShort -match "behind (\d+)") {
                $behind = [int]$Matches[1]
            }

            $syncStatus = if (-not $hasRemote) {
                "No Remote"
            }
            elseif ($ahead -gt 0) {
                "Ahead ($ahead)"
            }
            elseif ($behind -gt 0) {
                "Behind ($behind)"
            }
            else {
                "Up-to-date"
            }

            Pop-Location

            [PSCustomObject]@{
                Path       = $_.FullName
                Branch     = $branch
                Status     = if ($hasChanges) { "Dirty" } else { "Clean" }
                Untracked  = $untracked
                Remote     = if ($hasRemote) { "Yes" } else { "No" }
                Sync       = $syncStatus
                Ahead      = $ahead
            }
        }
        else {
            [PSCustomObject]@{
                Path = $_.FullName
                NonGit = $true
            }
        }

    } -ThrottleLimit $ThrottleLimit

    foreach ($r in $results) {
        if ($r.NonGit) {
            $nonGit += $r.Path
        } else {
            $gitRepos += $r
        }
    }

}
else {
    foreach ($folder in $projectFolders) {
        if (Test-Path (Join-Path $folder.FullName ".git")) {
            $gitRepos += Get-GitInfo $folder.FullName
        } else {
            $nonGit += $folder.FullName
        }
    }
}

# -----------------------------
# Filters
# -----------------------------

if ($OnlyDirty) {
    $gitRepos = $gitRepos | Where-Object { $_.Status -eq "Dirty" }
}

if ($OnlyNoRemote) {
    $gitRepos = $gitRepos | Where-Object { $_.Remote -eq "No" }
}

# -----------------------------
# Summary
# -----------------------------

$total = $projectFolders.Count
$gitCount = $gitRepos.Count
$nonGitCount = $nonGit.Count
$dirtyCount = ($gitRepos | Where-Object { $_.Status -eq "Dirty" }).Count
$noRemoteCount = ($gitRepos | Where-Object { $_.Remote -eq "No" }).Count
$aheadCount = ($gitRepos | Where-Object { $_.Ahead -gt 0 }).Count

Write-Host "`n📊 Repo Audit Summary" -ForegroundColor Cyan
Write-Host "────────────────────────────────────"
Write-Host "Total Projects     : $total"
Write-Host "Git Repos          : $gitCount"
Write-Host "Non-Git Folders    : $nonGitCount"
Write-Host "Dirty Repos        : $dirtyCount"
Write-Host "No Remote          : $noRemoteCount"
Write-Host "Ahead of Remote    : $aheadCount"
Write-Host "────────────────────────────────────`n"

if ($Summary) { return }

# -----------------------------
# Output Tables
# -----------------------------

Write-Host "📦 GIT REPOSITORIES`n" -ForegroundColor Green

$gitRepos |
    Select-Object Path, Branch, Status, Untracked, Remote, Sync |
    Format-Table -AutoSize

Write-Host "`n🚫 NON-GIT PROJECTS`n" -ForegroundColor Red

$nonGit | ForEach-Object { Write-Host "❌ $_" }

# -----------------------------
# Action Insights
# -----------------------------

Write-Host "`n⚠️ ACTION REQUIRED`n" -ForegroundColor Yellow

$noRemote = $gitRepos | Where-Object { $_.Remote -eq "No" }
$dirty = $gitRepos | Where-Object { $_.Status -eq "Dirty" }
$ahead = $gitRepos | Where-Object { $_.Ahead -gt 0 }

if ($noRemote) {
    Write-Host "🔸 No Remote:"
    $noRemote | ForEach-Object { Write-Host "   - $($_.Path)" }
}

if ($dirty) {
    Write-Host "`n🔸 Dirty Repos:"
    $dirty | ForEach-Object { Write-Host "   - $($_.Path) ($($_.Untracked) untracked)" }
}

if ($ahead) {
    Write-Host "`n🔸 Ahead of Remote:"
    $ahead | ForEach-Object { Write-Host "   - $($_.Path) ($($_.Ahead) commits)" }
}

Write-Host "`n✅ Done.`n"

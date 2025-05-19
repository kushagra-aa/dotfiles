# Alias
Set-Alias vim nvim
Set-Alias ll ls
Set-Alias g git
Set-Alias touch New-Item
Set-Alias treeEx Get-ChildItemsWithoutExcludedFolders

# for Starship Promt
Invoke-Expression (&starship init powershell)

# for Terminal Icons
Import-Module -Name Terminal-Icons

# for Posh Git
Import-Module posh-git

Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# Z Directory Jumpper
# Fuzzy Finder
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
  $Local:word = $wordToComplete.Replace('"', '""')
  $Local:ast = $commandAst.ToString().Replace('"', '""')
  winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}

# Utilities

function Which ($command) {
  Get-Command -Name $command -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

## File Utilities
# Copy a file
function CopyFile ($source, $destination) {
  # Check if source file exists
  if (-not (Test-Path $source)) {
    Write-Error "Error: Source file '$source' does not exist."
    return
  }
    
  # Copy the file with overwrite confirmation
  Copy-Item -Path $source -Destination $destination -Confirm:$true
}
  
# Move a file
function MoveFile ($source, $destination) {
  # Check if source file exists
  if (-not (Test-Path $source)) {
    Write-Error "Error: Source file '$source' does not exist."
    return
  }
  
  # Move the file with overwrite confirmation
  Move-Item -Path $source -Destination $destination -Confirm:$true
}
# Rename a file
function RenameFile ($oldName, $newName) {
  # Check if source file exists
  if (-not (Test-Path $oldName)) {
    Write-Error "Error: File '$oldName' does not exist."
    return
  }
  
  # Rename the file
  Rename-Item -Path $oldName -NewName $newName
}
# Check if file exists
function CheckFileExists ($path) {
  Test-Path $path
}
# Get file size
function GetFileSize ($path) {
  # Check if file exists
  if (-not (Test-Path $path)) {
    Write-Error "Error: File '$path' does not exist."
    return
  }
  
  # Get file size and convert to KB, MB, or GB
  $size = (Get-Item $path).Length
  $kb = $size / 1KB;
  $mb = $kb / 1MB;
  $gb = $mb / 1GB;
  
  if ($gb -gt 0.1) {
    return "{0:N2} GB" -f $gb
  }
  elseif ($mb -gt 0.1) {
    return "{0:N2} MB" -f $mb
  }
  else {
    return "{0:N0} KB" -f $kb
  }
}
# Get folder size (recursive)
function GetFolderSize ($path) {
  # Check if folder exists
  if (-not (Test-Path $path -PathType Container)) {
    Write-Error "Error: Folder '$path' does not exist."
    return
  }
  
  # Get total size of all files recursively
  return Get-ChildItem -Path $path -Recurse | Where-Object { $_.IsFile } | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum
}
# Create multiple files with same name
function MakeMultipleFilesSameName ($name, $count, $extension = ".txt") {
  # Validate input
  if ($count -lt 1) {
    Write-Error "Error: Please enter a positive number of files to create."
    return
  }
  
  # Create loop to generate filenames
  1..$count | ForEach-Object {
    $filename = "$name{0}$extension" -f $_
    New-Item -ItemType File -Path $filename
  }
  
  # Inform user
  Write-Host "Created $count files named '$name' with extension '$extension'."
}
# Make a File
function MakeFile ($target) {
  # Create file with error handling
  try {
    New-Item -ItemType File -Path $target
  }
  catch {
    Write-Error "Error creating file: $_"
  }
}
# Make directory and cd into it
function MakeNcd ($path) {
  # Create directory with error handling
  try {
    if (-not (Test-Path (Split-Path $path))) {
      New-Item -ItemType Directory -Path (Split-Path $path)
    }
    New-Item -ItemType Directory -Path $path
    Set-Location $path
  }
  catch {
    Write-Error "Error creating directory: $_"
  }
}
# Force remove files and directories
function RemoveF ($path = '.') {
  # Validate input (check if path exists)
  if (-not (Test-Path $path -PathType Container)) {
    Write-Error "Error: Path '$path' does not exist."
    return
  }
  
  # Capture remaining arguments as filenames
  $filenames = $args

  # Validate filenames (optional)
  if ($null -eq $filenames -or $filenames.Count -eq 0) {
    Write-Error "Error: Please provide at least one file to remove."
    return
  }
  
  # Loop through each filename
  foreach ($filename in $filenames) {
    $fullpath = Join-Path $path -ChildPath $filename
    # Confirm deletion for important files (optional)
    if ((Test-Path $fullpath).IsFile -and (Get-Item $fullpath).Attributes -like "*System*") {
      if (-not (Confirm-YesNo "Are you sure you want to delete '$fullpath' (system file)?")) {
        Write-Host "Deletion cancelled for '$fullpath'."
        continue
      }
    }
    
    # Remove the file with error handling
    try {
      Remove-Item $fullpath -Force
      Write-Host "Removed file: $filename"
    }
    catch {
      Write-Error "Error removing file '$filename': $_"
    }
  }
}
# Make Link file
function MakeLink ($target, $link) {
  # Check if target path exists
  if (-not (Test-Path $target)) {
    Write-Error "Error: Target path '$target' does not exist."
    return
  }
  
  # Create symbolic link with error handling
  try {
    New-Item -Path $link -ItemType SymbolicLink -Value $target
  }
  catch {
    Write-Error "Error creating symbolic link: $_"
  }
}
# Make Multiple Files
function MakeMultipleFiles ($path = '.') {
  # Validate input (check if path exists)
  if (-not (Test-Path $path -PathType Container)) {
    Write-Error "Error: Path '$path' does not exist."
    return
  }

  # Capture remaining arguments as filenames
  $filenames = $args
  Write-Host "filenames: '$filenames'"
  Write-Host "path: '$path'"

  # Validate input (check for empty string)
  if ($null -eq $filenames -or $filenames.Count -eq 0) {
    Write-Error "Error: Please provide at least one filename to create."
    return
  }
  
  # Loop through each filename
  foreach ($filename in $filenames) {
    $fullpath = Join-Path $path -ChildPath $filename
    # Create the file with error handling
    try {
      New-Item -ItemType File -Path $filename
    }
    catch {
      Write-Error "Error removing file '$fullpath': $_"
    }
  }
  Get-ChildItem;
}
# Remove all items in a path
function RemoveAllItems ($path) {
  # Validate input (check if path exists)
  if (-not (Test-Path $path -PathType Container)) {
    Write-Error "Error: Path '$path' does not exist."
    return
  }
  
  # Prompt for confirmation before deletion (highly recommended)
  if (-not (Confirm-YesNo "This will remove ALL items from '$path' permanently. Are you sure?")) {
    Write-Host "Deletion cancelled."
    return
  }
  
  # Remove items recursively with error handling
  try {
    Remove-Item $path -Recurse -Force
    Write-Host "Removed all items from path: $path"
  }
  catch {
    Write-Error "Error removing items from path '$path': $_"
  }
}
# Get folder size and size of all items
function GetFolderDetails ($path = '.') {
  # Validate input (check if path exists)
  if (-not (Test-Path $path -PathType Container)) {
    Write-Error "Error: Folder '$path' does not exist."
    return
  }

  # Get total folder size
  $totalSizeRaw = Get-ChildItem -Path $path -Recurse -Filter * | 
  Where-Object { $_.IsFile } | 
  Measure-Object -Property Length -Sum | 
  Select-Object -ExpandProperty Sum

  # Convert total size to appropriate unit and format
  $totalSizeUnit, $totalSizeFormatted = GetFormattedSize $totalSizeRaw
  Write-Host "Total size of folder '$path': $totalSizeFormatted $totalSizeUnit"

  # List child items with sizes and types
  Get-ChildItem -Path $path -Recurse | 
  ForEach-Object {
    $size = if ($_.PSIsContainer) { 0 } else { $_.Length }   # Set size to 0 for folders
    $sizeUnit, $sizeFormatted = GetFormattedSize $size
    $itemType = if ($_.PSIsContainer) { "Folder" } else { "File" }
    Write-Host ("{0,-30}" -f ($_.Name))  $sizeFormatted$sizeUnit  ($itemType)
  }
}
# Helper Function to determine appropriate size unit and formatting
function GetFormattedSize ($size) {
  if ($size -gt 1GB) {
    $unit = "GB"
    $formattedSize = ($size / 1GB).ToString("F2")
  }
  elseif ($size -gt 1MB) {
    $unit = "MB"
    $formattedSize = ($size / 1MB).ToString("F2")
  }
  else {
    $unit = "KB"
    $formattedSize = ($size / 1KB).ToString("F2")
  }
  return $unit, $formattedSize
}

function ListAllFilesAndFoders ($path) {
  tree /f /a $path
}

# List all disks in the system
function ListAllDisks () {
  Get-Disk | Select-Object Number, @{Name = "Size (GB)"; Expression = { $_.Size / 1GB } }, @{Name = "Free Space (GB)"; Expression = { $_.FreeSpace / 1GB } }, Status, MediaType
}
# List all Local Disks
function ListAllLocalDisks () {
  Get-PSDrive
}

function Get-ChildItemsWithoutExcludedFolders {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string[]]$ExcludeFolders = ("node_modules", ".next", ".pnpm-store")
    )

    Get-ChildItem -Path $Path -Force | ForEach-Object {
        if ($_.PSIsContainer -and ($ExcludeFolders -contains $_.Name)) {
            # Do nothing, effectively skipping these directories
        } else {
            $_ | Select-Object FullName, PSIsContainer
            if ($_.PSIsContainer) {
                Get-ChildItemsWithoutExcludedFolders -Path $_.FullName -ExcludeFolders $ExcludeFolders
            }
        }
    }
}
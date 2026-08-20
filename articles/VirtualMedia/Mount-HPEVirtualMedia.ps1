# 1. Define paths and size (Use .vhd temporarily so Windows can mount it)
$tempVhdPath = "C:\FAT16_Temp.vhd"
$finalImgPath = "C:\FAT16_Disk.img"
$sizeInBytes = 25MB
$sourceDir = "C:\MySourceFiles"

# 2. Check if source directory exists; create it if missing
if (-not (Test-Path -Path $sourceDir)) {
    New-Item -Path $sourceDir -ItemType Directory | Out-Null
    Write-Host "Created source directory at $sourceDir" -ForegroundColor Yellow
    Read-Host -Prompt "Place your files inside '$sourceDir', then press Enter to continue"
}

# 3. Clean up old files if they exist
Remove-Item -Path $tempVhdPath, $finalImgPath -ErrorAction SilentlyContinue

# 4. Create a VHD using DiskPart (native Windows tool)
$diskpartScript = @"
create vdisk file="$tempVhdPath" maximum=500 type=fixed
attach vdisk
convert mbr
create partition primary
format fs=fat quick label="FAT16_VOL"
assign
"@
$diskpartScript | diskpart

# 5. Get the mounted disk drive letter
$driveLetter = (Get-Volume | Where-Object { $_.FileSystemLabel -eq "FAT16_VOL" }).DriveLetter + ":"

# 6. Copy files if any exist
if (Get-ChildItem -Path $sourceDir) {
    Get-ChildItem -Path $sourceDir | Copy-Item -Destination "$driveLetter\" -Recurse -Force
    Write-Host "Files copied successfully." -ForegroundColor Green
} else {
    Write-Host "Source directory was empty. No files copied." -ForegroundColor Yellow
}

# 7. Detach the VHD cleanly using DiskPart
$detachScript = @"
select vdisk file="$tempVhdPath"
detach vdisk
"@
$detachScript | diskpart

# 8. Convert/Rename .vhd to .img
Move-Item -Path $tempVhdPath -Destination $finalImgPath -Force

Write-Host "FAT16 raw image created at $finalImgPath" -ForegroundColor Green
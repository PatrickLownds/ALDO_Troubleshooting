**Automating Air-Gapped Script Delivery for HPE ProLiant Gen11 Azure Local Nodes**

When preparing base images for Azure Local deployments, security best practices often require running custom PowerShell scripts, security hardening scripts, and pre-configuration tasks before network interfaces are physically connected to the network.

While HPE ProLiant Gen12 integrated Remote Console features make clipboard interaction and direct text passthrough effortless, Gen11 out-of-band management tools lack seamless copy-paste functionality during early boot and pre-network deployment phases. Manually typing long PowerShell commands into a bare console is both error-prone and inefficient.

To bridge this gap, the PowerShell script below automates the creation of a lightweight, bootable FAT16 raw disk image (.img). This image can be mounted directly to the host via iLO Virtual Media, allowing administrators to execute scripts locally on an isolated, air-gapped node prior to bringing network ports online.

To bridge this gap, the PowerShell script below automates the creation of a lightweight, bootable FAT16 raw disk image (.img). This image can be mounted directly to the host via iLO Virtual Media, allowing administrators to execute scripts locally on an isolated, air-gapped node prior to bringing network ports online.

```powershell
# 1. Define paths and size (Use .vhd temporarily so Windows can mount it)
$tempVhdPath = "C:\FAT16_Temp.vhd"
$finalImgPath = "C:\FAT16_Disk.img"
$sizeInBytes = 25MB$sourceDir = "C:\MySourceFiles"

# 2. Check if source directory exists; create it if missing
if (-not (Test-Path -Path $sourceDir)) {
    New-Item -Path $sourceDir -ItemType Directory | Out-Null
    Write-Host "Created source directory at $sourceDir" -ForegroundColor Yellow
    Read-Host -Prompt "Place your files inside '$sourceDir', then press Enter to continue"
}

# 3. Clean up old files if they exist
Remove-Item -Path $tempVhdPath,$finalImgPath -ErrorAction SilentlyContinue

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
$driveLetter = (Get-Volume \vert{} Where-Object {$_.FileSystemLabel -eq "FAT16_VOL" }).DriveLetter + ":"

# 6. Copy files if any exist
if (Get-ChildItem -Path $sourceDir) {
    Get-ChildItem -Path $sourceDir \vert{} Copy-Item -Destination "$driveLetter\" -Recurse -Force
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
Move-Item -Path $tempVhdPath -Destination$finalImgPath -Force

Write-Host "FAT16 raw image created at $finalImgPath" -ForegroundColor Green
```

**How the Script Works**

The automated process creates a temporary fixed virtual hard disk, formats it with a universally compatible FAT16 file system, copies your target payloads, and converts it into a raw image ready for out-of-band mounting:

1. **Environment & Directory Check:** Creates a local staging folder (C:\\MySourceFiles) if one does not exist, prompting you to drop your PowerShell scripts or modules inside.
2. **VHD Provisioning via DiskPart:** Generates a temporary fixed VHD, initialises an MBR partition table, and formats the volume as FAT16 to guarantee compatibility across legacy and out-of-band virtual media controllers.
3. **Payload Injection:** Automatically detects staged files in the source folder and copies them onto the mounted VHD volume.
4. **Image Finalisation:** Unmounts and detaches the virtual disk cleanly using diskpart, then converts the file extension to .img for immediate use with HPE iLO Virtual Media.


![HPE iLO 5 Virtual Floppy Mounting](/articles/VirtualMedia/iLO5%20Virtual%20Floppy.jpg) 


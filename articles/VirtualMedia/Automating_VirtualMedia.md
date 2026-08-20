**Automating Air-Gapped Script Delivery for HPE ProLiant Gen11 Azure Local Nodes**

When preparing base images for Azure Local deployments, security best practices often require running custom PowerShell scripts, security hardening scripts, and pre-configuration tasks before network interfaces are physically connected to the network.

While HPE ProLiant Gen12 integrated Remote Console features make clipboard interaction and direct text passthrough effortless, Gen11 out-of-band management tools lack seamless copy-paste functionality during early boot and pre-network deployment phases. Manually typing long PowerShell commands into a bare console is both error-prone and inefficient.

To bridge this gap, the PowerShell script below automates the creation of a lightweight, bootable FAT16 raw disk image (.img). This image can be mounted directly to the host via iLO Virtual Media, allowing administrators to execute scripts locally on an isolated, air-gapped node prior to bringing network ports online.

**How the Script Works**

The automated process creates a temporary fixed virtual hard disk, formats it with a universally compatible FAT16 file system, copies your target payloads, and converts it into a raw image ready for out-of-band mounting:

1. **Environment & Directory Check:** Creates a local staging folder (C:\\MySourceFiles) if one does not exist, prompting you to drop your PowerShell scripts or modules inside.
2. **VHD Provisioning via DiskPart:** Generates a temporary fixed VHD, initialises an MBR partition table, and formats the volume as FAT16 to guarantee compatibility across legacy and out-of-band virtual media controllers.
3. **Payload Injection:** Automatically detects staged files in the source folder and copies them onto the mounted VHD volume.
4. **Image Finalisation:** Unmounts and detaches the virtual disk cleanly using diskpart, then converts the file extension to .img for immediate use with HPE iLO Virtual Media.

* [**HPE iLO 5 Virtual Floppy Mounting**](/articles/VirtualMedia/iLO5%20Virtual%20Floppy.jpg) — Mounting `.img` payloads for out-of-band iLO virtual media injection.

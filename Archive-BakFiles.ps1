<#
.SYNOPSIS
  Archives all .bak files found under a given root directory, preserving the folder structure in a ZIP file and generating a manifest of original paths.
  By default, source files are NOT deleted after archiving (safe mode).

.PARAMETER RootPath
  Root folder from which to search for .bak files.

.PARAMETER DestinationZip
  (Optional) Output ZIP file path. If not provided, a timestamped name is generated next to the root folder.

.PARAMETER BatchSize
  (Optional) Number of files added to the ZIP per batch to avoid command line length limits. Default is 400.

.PARAMETER GenerateManifest
  (Optional) If specified, generates a CSV file with the complete list of archived files and their original paths.

.PARAMETER DeleteSourceFiles
  (Optional) If specified, deletes source .bak files after successful archiving.
  By default, source files are preserved (safe mode).
  ⚠️ WARNING: Deleting .bak files from Trellix ePO installation may VOID support!

.EXAMPLE
  .\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator"

.EXAMPLE
  .\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" -DestinationZip "c:\temp\bak_2025-09-08.zip" -GenerateManifest

.EXAMPLE
  .\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" -DeleteSourceFiles
  Archives and then deletes the original .bak files to free up space.
  ⚠️ Multiple confirmations required due to Trellix ePO support implications.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $false)]
    [string]$DestinationZip,

    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 5000)]
    [int]$BatchSize = 400,

    [Parameter(Mandatory = $false)]
    [switch]$GenerateManifest,

    [Parameter(Mandatory = $false)]
    [switch]$DeleteSourceFiles
)

try {
    # Validate root path
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "Root folder '$RootPath' not found."
    }

    # Normalize path
    $RootPath = (Resolve-Path -LiteralPath $RootPath).Path

    # Determine default ZIP name if not provided
    if (-not $DestinationZip) {
        $parent = Split-Path -Path $RootPath -Parent
        if (-not $parent) { $parent = $RootPath }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $DestinationZip = Join-Path -Path $parent -ChildPath "bak-archive_$timestamp.zip"
    } else {
        # Resolve absolute path for ZIP
        $zipParent = Split-Path -Path $DestinationZip -Parent
        $zipLeaf   = Split-Path -Path $DestinationZip -Leaf

        if (Test-Path -LiteralPath $zipParent) {
            $resolvedParent = (Resolve-Path -LiteralPath $zipParent).Path
            $DestinationZip = Join-Path $resolvedParent $zipLeaf
        } else {
            # Create parent directory if it doesn't exist
            New-Item -ItemType Directory -Path $zipParent -Force | Out-Null
            $DestinationZip = Join-Path $zipParent $zipLeaf
        }
    }

    Write-Verbose "Root folder  : $RootPath"
    Write-Verbose "Output ZIP   : $DestinationZip"

    # Retrieve .bak files (files only)
    $files = Get-ChildItem -LiteralPath $RootPath -Filter '*.bak' -File -Recurse -ErrorAction SilentlyContinue

    if (-not $files -or $files.Count -eq 0) {
        Write-Warning "No .bak files found under '$RootPath'."
        return
    }

    Write-Host ".bak files found: $($files.Count)"

    # Create manifest with detailed information
    $manifest = @()
    
    # Prepare relative paths to preserve folder structure in ZIP
    Push-Location -LiteralPath $RootPath
    try {
        $relativePaths = @()
        $fileCounter = 0
        
        foreach ($f in $files) {
            $fileCounter++
            Write-Progress -Activity "Analyzing .bak files" -Status "File $fileCounter/$($files.Count): $($f.Name)" -PercentComplete (($fileCounter / $files.Count) * 100)
            
            # Resolve-Path -Relative returns .\subfolder\file.bak
            $relativePath = Resolve-Path -LiteralPath $f.FullName -Relative
            $relativePaths += $relativePath
            
            # Calculate MD5 hash
            try {
                $md5Hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash
            }
            catch {
                $md5Hash = "ERROR: $($_.Exception.Message)"
                Write-Warning "Unable to calculate MD5 for $($f.FullName)"
            }
            
            # Add information to manifest
            $manifest += [PSCustomObject]@{
                OriginalFullPath     = $f.FullName
                RelativePathInZip    = $relativePath.TrimStart('.\')
                FileName             = $f.Name
                SizeKB               = [Math]::Round($f.Length / 1KB, 2)
                SizeMB               = [Math]::Round($f.Length / 1MB, 2)
                MD5Hash              = $md5Hash
                LastModified         = $f.LastWriteTime
                ArchivedDate         = Get-Date
            }
        }
        
        Write-Progress -Activity "Analyzing .bak files" -Completed

        # Create manifest.txt file in temporary directory
        $manifestTxtPath = Join-Path $env:TEMP "bak_manifest_$((Get-Date -Format 'yyyyMMdd_HHmmss')).txt"
        
        $manifestContent = @"
=============================================================================
.BAK FILES ARCHIVE MANIFEST
=============================================================================
Archive date     : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Analyzed root    : $RootPath
ZIP archive      : $DestinationZip
Number of files  : $($files.Count)
=============================================================================

"@
        
        foreach ($item in $manifest) {
            $manifestContent += @"
File: $($item.FileName)
  Original full path       : $($item.OriginalFullPath)
  Relative path in ZIP     : $($item.RelativePathInZip)
  Size                     : $($item.SizeKB) KB ($($item.SizeMB) MB)
  MD5 Hash                 : $($item.MD5Hash)
  Last modified            : $($item.LastModified)
  
"@
        }

        $manifestContent | Out-File -FilePath $manifestTxtPath -Encoding UTF8
        Write-Host "Manifest created: $manifestTxtPath"

        # Compress in batches to avoid command line length limits
        $total = $relativePaths.Count
        for ($i = 0; $i -lt $total; $i += $BatchSize) {
            $end = [Math]::Min($i + $BatchSize - 1, $total - 1)
            $chunk = $relativePaths[$i..$end]
            Compress-Archive -Path $chunk -DestinationPath $DestinationZip -Update -CompressionLevel Optimal
            Write-Host ("Adding to ZIP: {0}/{1}" -f ($end + 1), $total)
        }

        # Add manifest to ZIP
        Push-Location (Split-Path $manifestTxtPath)
        try {
            $manifestFileName = Split-Path $manifestTxtPath -Leaf
            Compress-Archive -Path $manifestFileName -DestinationPath $DestinationZip -Update
            Write-Host "Manifest added to ZIP"
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Pop-Location
    }

    # Delete source files if requested
    if ($DeleteSourceFiles) {
        Write-Host "`n" -NoNewline
        Write-Host "=============================================================================" -ForegroundColor Red -BackgroundColor Black
        Write-Host "                            ⚠️  CRITICAL WARNING  ⚠️                          " -ForegroundColor Red -BackgroundColor Black
        Write-Host "=============================================================================" -ForegroundColor Red -BackgroundColor Black
        Write-Host ""
        Write-Host "  DELETING .BAK FILES FROM TRELLIX ePO INSTALLATION DIRECTORY" -ForegroundColor Red -BackgroundColor Black
        Write-Host ""
        Write-Host "  ⛔ THIS ACTION WILL VOID YOUR TRELLIX SUPPORT ⛔" -ForegroundColor Red -BackgroundColor Black
        Write-Host ""
        Write-Host "  Removing backup files from the ePO installation may:" -ForegroundColor Yellow
        Write-Host "  • Make your installation UNSUPPORTED by Trellix Technical Support" -ForegroundColor Yellow
        Write-Host "  • Prevent rollback capabilities in case of system issues" -ForegroundColor Yellow
        Write-Host "  • Violate compliance and audit requirements" -ForegroundColor Yellow
        Write-Host "  • Result in inability to restore previous configurations" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  THIS OPERATION IS PERMANENT AND CANNOT BE UNDONE!" -ForegroundColor Red -BackgroundColor Black
        Write-Host ""
        Write-Host "=============================================================================" -ForegroundColor Red -BackgroundColor Black
        Write-Host "`n"
        
        # First pop-up confirmation
        Add-Type -AssemblyName System.Windows.Forms
        $result1 = [System.Windows.Forms.MessageBox]::Show(
            "⚠️ CRITICAL WARNING ⚠️`n`n" +
            "You are about to DELETE source .bak files from:`n" +
            "$RootPath`n`n" +
            "⛔ THIS WILL VOID YOUR TRELLIX ePO SUPPORT ⛔`n`n" +
            "Deleting backup files from ePO installation directory may make your " +
            "system UNSUPPORTED by Trellix Technical Support and prevent system recovery.`n`n" +
            "Are you ABSOLUTELY SURE you want to proceed?",
            "⚠️ Trellix ePO - Support Risk Warning",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result1 -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Operation CANCELLED by user. Source files preserved." -ForegroundColor Green
            Write-Host "Archive created successfully without deleting source files."
            return
        }
        
        # Second pop-up confirmation (more aggressive)
        $result2 = [System.Windows.Forms.MessageBox]::Show(
            "⛔ FINAL CONFIRMATION REQUIRED ⛔`n`n" +
            "This is your LAST CHANCE to cancel!`n`n" +
            "Deleting these files will:`n" +
            "• VOID Trellix Technical Support for this ePO installation`n" +
            "• PERMANENTLY delete $($files.Count) backup file(s)`n" +
            "• PREVENT system rollback capabilities`n" +
            "• This action CANNOT be undone`n`n" +
            "Type 'DELETE' in the next prompt to confirm deletion, or click No to cancel.",
            "⛔ FINAL WARNING - Confirm Deletion",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        if ($result2 -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "Operation CANCELLED by user. Source files preserved." -ForegroundColor Green
            Write-Host "Archive created successfully without deleting source files."
            return
        }
        
        # Third confirmation - typed confirmation
        Write-Host "`nFINAL CONFIRMATION: Type 'DELETE' (in capital letters) to proceed: " -ForegroundColor Red -NoNewline
        $confirmation = Read-Host
        
        if ($confirmation -ne "DELETE") {
            Write-Host "`nOperation CANCELLED. You did not type 'DELETE' correctly." -ForegroundColor Green
            Write-Host "Source files preserved. Archive created successfully."
            return
        }
        
        Write-Host "`n=== DELETING SOURCE FILES ===" -ForegroundColor Red
        Write-Host "⚠️ Proceeding with permanent deletion..." -ForegroundColor Yellow
        
        $deletedCount = 0
        $failedCount = 0
        
        foreach ($file in $files) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $deletedCount++
                Write-Verbose "Deleted: $($file.FullName)"
            }
            catch {
                $failedCount++
                Write-Warning "Failed to delete: $($file.FullName) - $($_.Exception.Message)"
            }
        }
        
        Write-Host "`nDeletion Summary:" -ForegroundColor Yellow
        Write-Host "Successfully deleted: $deletedCount file(s)" -ForegroundColor $(if ($deletedCount -gt 0) { "Red" } else { "Gray" })
        if ($failedCount -gt 0) {
            Write-Warning "Failed to delete: $failedCount file(s)"
        }
        Write-Host "`n⚠️ REMINDER: Your Trellix ePO support may be affected by this deletion." -ForegroundColor Red
    } else {
        Write-Host "`nSource files preserved (safe mode). Use -DeleteSourceFiles to remove originals."
    }

    # Generate CSV file if requested
    if ($GenerateManifest) {
        $csvPath = $DestinationZip -replace '\.zip$', '_manifest.csv'
        $manifest | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "CSV manifest generated: $csvPath"
    }

    Write-Host "`n=== ARCHIVE COMPLETED ==="
    Write-Host "Source files      : $($files.Count)"
    Write-Host "Archive ZIP       : $DestinationZip"
    Write-Host "Manifest (text)   : Included in ZIP"
    if ($GenerateManifest) {
        Write-Host "Manifest (CSV)    : $csvPath"
    }
    if ($DeleteSourceFiles) {
        Write-Host "Source files      : DELETED"
    } else {
        Write-Host "Source files      : PRESERVED"
    }

    # Display preview of original paths
    Write-Host "`n=== ARCHIVED FILES PREVIEW ==="
    $manifest | Select-Object -First 5 FileName, OriginalFullPath, SizeKB, MD5Hash | Format-Table -AutoSize
    if ($manifest.Count -gt 5) {
        Write-Host "... and $($manifest.Count - 5) more file(s)"
    }
}
catch {
    Write-Error "ERROR: $($_.Exception.Message)"
    exit 1
}

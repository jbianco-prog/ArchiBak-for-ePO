<#
.SYNOPSIS
  Archives all .bak files found under a given root directory, preserving
  the folder structure in a ZIP file and generating a manifest of original paths.

.PARAMETER RootPath
  Root folder from which to search for .bak files.

.PARAMETER DestinationZip
  (Optional) Output ZIP file path. If not provided, a timestamped name
  is generated next to the root folder.

.PARAMETER BatchSize
  (Optional) Number of files added to the ZIP per batch to avoid
  command line length limits. Default is 400.

.PARAMETER GenerateManifest
  (Optional) If specified, generates a CSV file with the complete list
  of archived files and their original paths.

.EXAMPLE
  .\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\Test"

.EXAMPLE
  .\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\Test" -DestinationZip "c:\SSL\bak_2025-09-08.zip" -GenerateManifest
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
    [switch]$GenerateManifest
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

    # Generate CSV file if requested
    if ($GenerateManifest) {
        $csvPath = $DestinationZip -replace '\.zip$', '_manifest.csv'
        $manifest | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "CSV manifest generated: $csvPath"
    }

    Write-Host "`n=== ARCHIVE COMPLETED ==="
    Write-Host "Source files      : $($files.Count)"
    Write-Host "ZIP archive       : $DestinationZip"
    Write-Host "Manifest (text)   : Included in ZIP"
    if ($GenerateManifest) {
        Write-Host "Manifest (CSV)    : $csvPath"
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

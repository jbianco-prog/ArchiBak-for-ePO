# Archive-BakFiles - PowerShell Backup Archiver for Trellix ePO 5.10 OnPremise (Unsupported, Community ressource)
> A robust PowerShell script that archives all `.bak` files found in a directory tree while preserving the original folder structure and generating a detailed manifest with MD5 checksums.

## Features

- 🔍 **Recursive search**: Automatically finds all `.bak` files in subdirectories
- 📦 **Structure preservation**: Maintains original folder hierarchy in ZIP archive
- 🔐 **MD5 checksums**: Calculates MD5 hash for each file to verify integrity
- 📋 **Detailed manifest**: Generates comprehensive documentation of archived files
- 📊 **Progress tracking**: Real-time progress bar during file analysis
- 💾 **Batch processing**: Handles large file sets efficiently (configurable batch size)
- 📄 **Multiple output formats**: Text manifest in ZIP + optional CSV export

## Requirements

- Windows PowerShell 5.1 or later
- PowerShell Core 7.x (cross-platform compatible)
- Appropriate read permissions on source directory
- Write permissions on destination directory

## Installation

1. Download the `Archive-BakFiles.ps1` script
2. Place it in a convenient location
3. No additional installation required

## Usage

### Basic usage

Archive all `.bak` files with auto-generated ZIP name:

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator"
```

### Specify custom ZIP Name

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" -DestinationZip "C:\Archives\backup_2025-10-29.zip"
```

### Generate additional CSV manifest

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" -GenerateManifest
```

### Advanced usage with all options

```powershell
.\Archive-BakFiles.ps1 `
    -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" `
    -DestinationZip "D:\Backups\mcafee_bak_archive.zip" `
    -BatchSize 500 `
    -GenerateManifest `
    -Verbose
```

### Archive and delete source files (space cleanup)

```powershell
# Verify archive first, then delete sources to free up disk space
.\Archive-BakFiles.ps1 `
    -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" `
    -DestinationZip "D:\Archives\old_backups.zip" `
    -DeleteSourceFiles `
    -GenerateManifest
```

⚠️ **Important**: Always verify the archive is complete and readable before using `-DeleteSourceFiles`!

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `RootPath` | String | Yes | - | Root directory to search for `.bak` files |
| `DestinationZip` | String | No | Auto-generated | Output ZIP file path |
| `BatchSize` | Integer | No | 400 | Number of files per compression batch (50-5000) |
| `GenerateManifest` | Switch | No | False | Generate additional CSV manifest file |
| `DeleteSourceFiles` | Switch | No | False | **Delete** source files after archiving (⚠️ use with caution) |

## Default behavior (Safe Mode)

**By default, the script does NOT delete source files.** This is the safest approach:

- ✅ Original `.bak` files remain in their original locations
- ✅ You can verify the archive before removing sources
- ✅ No risk of data loss if archiving fails
- ✅ Allows for comparison between original and archived files
- ✅ Maintains Trellix ePO support compliance

### Deleting source files

To delete source files after successful archiving, use the `-DeleteSourceFiles` flag:

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" -DeleteSourceFiles
```

⚠️ **CRITICAL WARNING FOR TRELLIX ePO INSTALLATIONS**: 

When using `-DeleteSourceFiles` on a Trellix ePO installation directory, the script will:

1. **Display a critical warning banner** in RED explaining support implications
2. **Show first pop-up warning** about voiding Trellix Technical Support
3. **Show second pop-up confirmation** (final warning with error icon)
4. **Require typed confirmation** - You must type 'DELETE' in capital letters
5. Only after all 3 confirmations will proceed with deletion

**Why these warnings?**
- ⛔ Deleting .bak files from ePO installation **may VOID Trellix Technical Support**
- ⛔ Prevents system rollback and recovery capabilities
- ⛔ May violate compliance and audit requirements
- ⛔ This operation is **PERMANENT and CANNOT be undone**

The script will:
1. Create the archive first
2. Display multiple warnings about Trellix ePO support implications
3. Require multiple confirmations (2 pop-ups + 1 typed)
4. Delete each file individually
5. Report success/failure for each deletion

## Output

### ZIP Archive contents

The ZIP file contains:
- All `.bak` files with preserved folder structure
- `bak_manifest_[timestamp].txt` - Detailed text manifest

### Manifest information

Each archived file is documented with:

| Field | Description |
|-------|-------------|
| **Original Full Path** | Complete original file path |
| **Relative Path in ZIP** | Path within the archive |
| **File Name** | Name of the file |
| **Size (KB)** | File size in kilobytes |
| **Size (MB)** | File size in megabytes |
| **MD5 Hash** | MD5 checksum for integrity verification |
| **Last Modified** | Original file modification date |
| **Archived Date** | Date when archive was created |

### Manifest example

```
=============================================================================
.BAK FILES ARCHIVE MANIFEST
=============================================================================
Archive date     : 2025-10-29 14:32:15
Analyzed root    : C:\Program Files (x86)\McAfee\ePolicy Orchestrator
ZIP archive      : C:\Program Files (x86)\McAfee\bak-archive_20251029_143215.zip
Number of files  : 127
=============================================================================

File: database.bak
  Original full path       : C:\Program Files (x86)\McAfee\ePolicy Orchestrator\db\database.bak
  Relative path in ZIP     : db\database.bak
  Size                     : 2048.75 KB (2.00 MB)
  MD5 Hash                 : 5D41402ABC4B2A76B9719D911017C592
  Last modified            : 2025-10-15 10:23:45
```

### Console output

During execution, the script displays:
- Number of `.bak` files found
- Real-time progress bar with file count
- Batch compression progress
- Preview table of first 5 archived files
- Summary statistics

### Optional CSV export

When using `-GenerateManifest`, creates `[zipname]_manifest.csv` containing all manifest data in spreadsheet-compatible format.

## Examples

### Example 1: Simple archive

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Data"
```

**Output**: `C:\bak-archive_20251029_143215.zip` with embedded manifest

### Example 2: Custom location with CSV

```powershell
.\Archive-BakFiles.ps1 `
    -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" `
    -DestinationZip "D:\Backups\webapp_backup.zip" `
    -GenerateManifest
```

**Output**: 
- `D:\Backups\webapp_backup.zip` (archive with manifest)
- `D:\Backups\webapp_backup_manifest.csv` (spreadsheet)

### Example 3: Large file set

```powershell
.\Archive-BakFiles.ps1 `
    -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" `
    -BatchSize 1000 `
    -Verbose
```

**Output**: Optimized for large number of files with verbose logging

## Error handling

The script includes robust error handling:

- ✅ Validates root path exists
- ✅ Creates destination directory if needed
- ✅ Handles MD5 calculation failures gracefully
- ✅ Provides clear error messages
- ✅ Uses exit code 1 on failure

## Performance considerations

- **Batch size**: Default 400 files per batch prevents command line overflow
- **MD5 calculation**: May take time for large files; progress is displayed
- **Memory usage**: Efficient for thousands of files
- **Network paths**: Supported but may be slower (UNC paths)

## Restoring files

To restore files from the archive:

1. Extract the ZIP file
2. Consult the manifest (text or CSV) to locate original paths
3. Copy files to their original locations
4. Optionally verify MD5 hashes to ensure integrity

### Verification example

```powershell
# Verify a restored file
$manifest = Import-Csv "backup_manifest.csv"
$file = $manifest | Where-Object { $_.FileName -eq "database.bak" }
$currentHash = (Get-FileHash -Path $file.OriginalFullPath -Algorithm MD5).Hash

if ($currentHash -eq $file.MD5Hash) {
    Write-Host "File integrity verified ✓"
} else {
    Write-Host "File integrity check FAILED ✗"
}
```

## Troubleshooting

### No files found

**Issue**: "No .bak files found under..."

**Solution**: 
- Verify the path is correct
- Check file permissions
- Ensure `.bak` files exist in subdirectories

### Access denied

**Issue**: Permission errors

**Solution**:
- Run PowerShell as Administrator
- Check NTFS permissions on source/destination
- Verify antivirus isn't blocking access

### Command line too long

**Issue**: Error during compression

**Solution**:
- Reduce `-BatchSize` parameter (e.g., `-BatchSize 200`)
- This is rare but can occur with very long path names

## Best practices

1. **Test First**: Run on a small subset before large archives
2. **Keep Manifests**: Store CSV manifests separately for quick reference
3. **Verify Archives**: Periodically test ZIP file integrity
4. **Regular Archives**: Schedule script execution for routine backups
5. **Network Drives**: Use local drives for better performance
6. **Safe Deletion Workflow**:
   - Archive files WITHOUT `-DeleteSourceFiles` first
   - Extract and verify a few random files from the archive
   - Check the manifest for completeness
   - Only then re-run with `-DeleteSourceFiles` if you need to free space
7. **Keep Original Backups**: Consider keeping at least one generation of source files before deletion
8. **Trellix ePO Specific**:
   - **NEVER** use `-DeleteSourceFiles` on production ePO servers without approval
   - Consult Trellix support before removing any .bak files from ePO directory
   - Maintain backup retention policy aligned with compliance requirements
   - Consider moving files instead of deleting them

## Security considerations

- MD5 hashes provide integrity checking (not cryptographic security)
- Manifests contain full file paths (sensitive information)
- ZIP files are not encrypted by default
- Consider additional encryption for sensitive data

## Trellix ePO specific warnings

⚠️ **CRITICAL: If you are archiving files from a Trellix ePolicy Orchestrator (ePO) installation:**

### Do NOT use `-DeleteSourceFiles` unless absolutely necessary

Deleting `.bak` files from your ePO installation directory can have serious consequences:

- **Support Implications**: May void or complicate Trellix Technical Support
- **Recovery Risk**: Removes your ability to rollback configurations
- **Compliance Issues**: May violate internal audit and compliance requirements
- **Best Practice Violation**: Trellix recommends maintaining backup files

### If you must delete files

The script includes **triple confirmation** protection:
1. Large RED warning banner in console
2. First pop-up dialog about support implications
3. Second pop-up with error icon (final warning)
4. Typed confirmation required (must type 'DELETE')

You can cancel at any point during these confirmations.

### Recommended approach for ePO

Instead of using `-DeleteSourceFiles`, consider:
1. Archive files to external storage
2. Verify archive integrity
3. Move (don't delete) old .bak files to a separate retention folder
4. Maintain at least one generation of backups
5. Consult Trellix support before removing any files

## License

This script is provided as-is for use in backup and archival operations.

## Support

For issues or questions:
- Review the manifest for troubleshooting
- Check PowerShell execution policy: `Get-ExecutionPolicy`
- Enable verbose output with `-Verbose` flag

## Version history

- **v2.0** - Added MD5 checksums
- **v1.0** - Initial release with basic archiving

## Contributing

Suggestions for improvements:
- Support for other file extensions
- SHA256 hash option
- Compression level parameter
- Exclusion filters
- Email notifications

---

**Last updated**: October 29, 2025

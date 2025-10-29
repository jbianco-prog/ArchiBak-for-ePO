# Archive-BakFiles - PowerShell Backup Archiver
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

### Basic Usage

Archive all `.bak` files with auto-generated ZIP name:

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator"
```

### Specify Custom ZIP Name

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" -DestinationZip "C:\Archives\backup_2025-10-29.zip"
```

### Generate Additional CSV Manifest

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\MyData" -GenerateManifest
```

### Advanced Usage with All Options

```powershell
.\Archive-BakFiles.ps1 `
    -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator" `
    -DestinationZip "D:\Backups\mcafee_bak_archive.zip" `
    -BatchSize 500 `
    -GenerateManifest `
    -Verbose
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `RootPath` | String | Yes | - | Root directory to search for `.bak` files |
| `DestinationZip` | String | No | Auto-generated | Output ZIP file path |
| `BatchSize` | Integer | No | 400 | Number of files per compression batch (50-5000) |
| `GenerateManifest` | Switch | No | False | Generate additional CSV manifest file |

## Output

### ZIP Archive Contents

The ZIP file contains:
- All `.bak` files with preserved folder structure
- `bak_manifest_[timestamp].txt` - Detailed text manifest

### Manifest Information

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

### Manifest Example

```
=============================================================================
.BAK FILES ARCHIVE MANIFEST
=============================================================================
Archive date     : 2025-10-29 14:32:15
Analyzed root    : C:\Program Files (x86)\McAfee\ePolicy Orchestrator
ZIP archive      : C:\temp\bak-archive_20251029_143215.zip
Number of files  : 127
=============================================================================

File: database.bak
  Original full path       : C:\Program Files (x86)\McAfee\ePolicy Orchestrator\data\database.bak
  Relative path in ZIP     : DB\database.bak
  Size                     : 2048.75 KB (2.00 MB)
  MD5 Hash                 : 5D41402ABC4B2A76B9719D911017C592
  Last modified            : 2025-10-15 10:23:45
```

### Console Output

During execution, the script displays:
- Number of `.bak` files found
- Real-time progress bar with file count
- Batch compression progress
- Preview table of first 5 archived files
- Summary statistics

### Optional CSV Export

When using `-GenerateManifest`, creates `[zipname]_manifest.csv` containing all manifest data in spreadsheet-compatible format.

## Examples

### Example 1: Simple archive

```powershell
.\Archive-BakFiles.ps1 -RootPath "C:\Program Files (x86)\McAfee\ePolicy Orchestrator"
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

### Verification Example

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

1. **Test first**: Run on a small subset before large archives
2. **Keep manifests**: Store CSV manifests separately for quick reference
3. **Verify archives**: Periodically test ZIP file integrity
4. **Regular archives**: Schedule script execution for routine backups
5. **Network drives**: Use local drives for better performance

## Security considerations

- MD5 hashes provide integrity checking (not cryptographic security)
- Manifests contain full file paths (sensitive information)
- ZIP files are not encrypted by default
- Consider additional encryption for sensitive data

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

---

**Last updated**: October 29, 2025

# photo-rename

PowerShell/BAT scripts to batch-rename photos in chronological order while keeping RAW+JPEG+XMP groups together, and to clean up orphan XMP sidecars. Built for merging photo folders that got split in the middle of a shoot sequence.

> Note: the scripts' comments and interactive prompts are in Portuguese (personal workflow). This README documents everything in English.

## The problem

When photo folders get split mid-sequence (backup restores, multiple memory cards, merging exports), you end up with clashing camera filenames (`DSC_0001` in two different folders meaning two different photos). Merging them requires renaming everything into one clean chronological sequence — without separating a RAW file from its JPEG and its XMP sidecar.

## The scripts

### 1. `RenomearFotos.bat` — entry point
Interactive wrapper. Copy it **together with the `.ps1`** into the photo folder and double-click. It will:
- Ask for today's date as a safety confirmation (anti-accident lock)
- Ask for the filename prefix: `.` = `DSC_` (Nikon-style), `,` = `DSCF` (Fujifilm-style), or any custom prefix (e.g. `IMG_`)
- Ask for the starting number of the sequence
- Call the PowerShell script targeting the current folder

### 2. `Rename_PowershellScript_com_argumento.ps1` — the engine
Does the actual renaming:
- Collects JPG, NEF, RAF and XMP files (non-recursive)
- Groups files by base name — `DSC_0007.nef` + `DSC_0007.jpg` + `DSC_0007.xmp` stay together under the same new number
- Sorts groups by modification date, so the new sequence follows real shooting order
- Renames sequentially (`DSC_0001`, `DSC_0002`, ...) and **moves results to a `renamed/` subfolder** (never renames in place)
- Preserves the leading `_` used by Capture One for AdobeRGB exports (`_DSC_0007.jpg` → `_DSC_0042.jpg`)
- Skips groups that contain only XMPs (no real photo)
- Always runs a dry-run first, then requires `y` + today's date to execute for real
- Writes a full log to `moveLog.txt`
- Destination conflicts are skipped and logged as `CONFLICT`

Standalone usage:

```powershell
# Dry-run in current folder with prefix DSC_
powershell -File .\Rename_PowershellScript_com_argumento.ps1

# Specific folder, custom prefix, starting at 42
powershell -File .\Rename_PowershellScript_com_argumento.ps1 -folder "F:\2024\Session" -prefix "IMG_" -startNum 42
```

### 3. `mover_xmp_orfaos.ps1` — orphan XMP cleanup
XMP files are sidecars (edits, ratings, metadata from Capture One/Lightroom) that live next to their image. When an image is deleted or moved, its XMP can be left behind — an "orphan".

This script walks the folder tree recursively and moves orphan XMPs into a `_xmp/` subfolder inside each folder. It recognizes both sidecar styles:

| Image | Sidecar | Orphan? |
|---|---|---|
| `DSC_0001.nef` exists | `DSC_0001.xmp` | No |
| `DSC_0001.nef` exists | `DSC_0001.nef.xmp` | No |
| *(missing)* | `DSC_0001.xmp` | Yes |
| *(missing)* | `DSC_0001.nef.xmp` | Yes |

Usage: open PowerShell in the target folder, paste the script (or run the file) with `$DryRun = $true` to preview, then set `$DryRun = $false` to actually move.

## Typical workflow

1. Dump the photos from the split folders into one folder
2. Copy `RenomearFotos.bat` + the `.ps1` there and run the `.bat`
3. Review the dry-run output, confirm with `y` + today's date
4. Renamed files land in `renamed/` — check the sequence, then move them wherever they belong
5. Run `mover_xmp_orfaos.ps1` to sweep leftover orphan sidecars into `_xmp/`

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- No external dependencies

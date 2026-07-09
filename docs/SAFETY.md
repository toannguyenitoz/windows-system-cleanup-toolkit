# Safety Guide

Windows CleanSweep Toolkit is designed for conservative cleanup.

## What the script can delete

Only temporary files older than the selected number of days are deleted in cleanup mode.

## What the script only reports

- Windows Update cache
- Browser cache
- Downloads folder files
- Crash dumps
- Startup items
- Broken shortcuts
- Dead PATH entries
- Developer caches

## Recommended workflow

1. Run scan mode first.
2. Review the CSV or HTML report.
3. Close browsers and Office apps.
4. Run cleanup mode only when ready.
5. Restart Windows if cleanup was part of troubleshooting.

## Do not use this tool to delete

- User documents
- Downloads without review
- Program Files folders
- WinSxS
- System32
- Unknown business application folders

# Troubleshooting

## PowerShell says scripts are disabled

Run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Script downloaded from internet is blocked

Run:

```powershell
Unblock-File .\scripts\CleanSweep.ps1
```

## Some files cannot be deleted

This is normal. Windows locks files that are currently in use.

Recommended actions:

- Close apps.
- Run the script as Administrator.
- Restart the computer.
- Run cleanup again.

## Reports folder is missing

The script creates the `reports` folder automatically.

## Browser cache remains large

Close all browser windows first. Browser cache is reported by default and not deleted automatically in the current safe version.

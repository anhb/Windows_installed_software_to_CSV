# ----------------------------------------------------------------------------------
# SCRIPT FOR GETTING APPS INSTALLED IN A SERVER USING IntallLocation AND Registers
# ----------------------------------------------------------------------------------

$OutputFilePath = "C:\YourUser\Software-Installed.csv"

$RegistryPaths = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" ; Arch = "64-bit" },
    @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" ; Arch = "32-bit (WOW64)" }
)

# Default Value '*' =  Everything
$CustomFilterPrefix = "*"

$CustomInventoryPaths = @(
    "C:\Tools",        
    "D:\PortableApps", 
    "E:\CustomScripts"
)

$InstalledSoftware = @()

foreach ($RegEntry in $RegistryPaths) {
    $Path = $RegEntry.Path
    $Arch = $RegEntry.Arch

    Write-Host "--- Processing inputs $Arch in $Path ---" -ForegroundColor Cyan
    
    $RegEntriesData = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.DisplayName -ne $null -and $_.SystemComponent -ne 1 -and $_.ParentKeyName -eq $null
        }
    
    foreach ($App in $RegEntriesData) {
        $ProgramName = $App.DisplayName
        $InstallPath = $App.InstallLocation
        
        $SizeInMB = "N/A - No Home Path"
        $SizeInGB = "N/A - No Home Path"
        $HomeLocation = $InstallPath
        
        if ($InstallPath -ne $null -and $InstallPath -ne "" -and (Test-Path -Path $InstallPath -PathType Container)) {
            
            Write-Host "Calculating Size of: $ProgramName..." -ForegroundColor Yellow
            try {
                $SizeInBytes = (Get-ChildItem -Path $InstallPath -File -Recurse -ErrorAction Stop | 
                                Measure-Object -Property Length -Sum).Sum
                
                $SizeInMB = [Math]::Round($SizeInBytes / 1MB, 2)
                $SizeInGB = [Math]::Round($SizeInBytes / 1GB, 2)
            }
            catch {
                Write-Host "CALCULATING SIZE ERROR OF '$ProgramName': $($_.Exception.Message)" -ForegroundColor Red
                $SizeInMB = "ACCESSING ERROR"
                $SizeInGB = "ACCESSING ERROR"
            }
        } 
        elseif ($InstallPath -ne $null -and $InstallPath -ne "") {
            $HomeLocation = "$InstallPath (Registered Path, Folder Lost)"
        }
        else {
            $HomeLocation = "Not Registered (Typical for MSI/Components)"
        }


        $InstalledSoftware += [PSCustomObject]@{
            'Editor'              = $App.Publisher
            'Program Name' = $ProgramName
            'Version'             = $App.DisplayVersion
            'Architecture' = $Arch
            'HOME (Main Path)' = $HomeLocation
            'Size (MB)'         = $SizeInMB
            'Size (GB)'         = $SizeInGB
            'Path (Installer)'   = $App.InstallSource
            'Path (Uninstaller)' = $App.UninstallString
        }
    }
}

Write-Host ""
Write-Host "--- Starting Custom/Portable Path Scan ---" -ForegroundColor Yellow

foreach ($CustomPath in $CustomInventoryPaths) {
    
    if (Test-Path -Path $CustomPath -PathType Container) {
        
        $CustomFolders = @()
        
        # Determine scanning depth based on prefix filter
        if ($CustomFilterPrefix -ne "*") {
            # Deep scan (Recursive) - required when looking for a specific prefix at any depth
            Write-Host "Scanning directory RECURSIVELY: $CustomPath (Filter: '$CustomFilterPrefix*')" -ForegroundColor Green
            $CustomFolders = Get-ChildItem -Path $CustomPath -Directory -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$CustomFilterPrefix*" }
        } else {
            # Shallow scan (Non-recursive) - default behavior when looking for all immediate subfolders
            Write-Host "Scanning directory SHALLOWLY: $CustomPath (Filter: '$CustomFilterPrefix*')" -ForegroundColor Green
            # Note: The -Recurse parameter is omitted here
            $CustomFolders = Get-ChildItem -Path $CustomPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$CustomFilterPrefix*" }
        }
        
        if ($CustomFolders.Count -eq 0) {
            Write-Host "No folders matching '$CustomFilterPrefix*' found in $CustomPath. Skipping." -ForegroundColor DarkYellow
            continue
        }

        foreach ($Folder in $CustomFolders) {
            $ProgramName = $Folder.Name
            $InstallPath = $Folder.FullName
            
            Write-Host "Calculating Size of Portable App: $ProgramName..." -ForegroundColor DarkYellow
            
            $SizeInMB = "0.00"
            $SizeInGB = "0.00"
            
            try {
                $SizeInBytes = (Get-ChildItem -Path $InstallPath -File -Recurse -ErrorAction Stop | 
                                Measure-Object -Property Length -Sum).Sum
                                
                $SizeInMB = [Math]::Round($SizeInBytes / 1MB, 2)
                $SizeInGB = [Math]::Round($SizeInBytes / 1GB, 2)
                
            } catch {
                Write-Host "CALCULATING SIZE ERROR FOR '$ProgramName' (Portable): $($_.Exception.Message)" -ForegroundColor Red
                $SizeInMB = "ACCESSING ERROR"
                $SizeInGB = "ACCESSING ERROR"
            }
            
            # Add the portable application entry
            $InstalledSoftware += [PSCustomObject]@{
                'Editor'              = "Custom/Portable"
                'Program Name'        = $ProgramName
                'Version'             = "Unknown"
                'Architecture'        = "Portable/Custom"
                'HOME (Main Path)'    = $InstallPath
                'Size (MB)'           = $SizeInMB
                'Size (GB)'           = $SizeInGB
                'Path (Installer)'    = "N/A - Portable"
                'Path (Uninstaller)'  = "N/A - Portable"
            }
        }
    } else {
        Write-Host "WARNING: Custom path '$CustomPath' not found. Skipping." -ForegroundColor Red
    }
}

$InstalledSoftware | Sort-Object -Property 'Size (MB)' -Descending |
    Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "********************************************************************************"
Write-Host "PROCESS COMPLETED!" -ForegroundColor Green
Write-Host "The COMPLETE inventory (Registry & Custom) has been saved to: $OutputFilePath" -ForegroundColor Green
Write-Host "********************************************************************************"


# Backup-TeamsConfig.ps1

Param (

    [Parameter(mandatory = $true)][ValidateSet('Backup', 'Compare')][string]$Action,
    [Parameter(mandatory = $false)][string]$Path,
    [Parameter(mandatory = $false)][uri]$SendToFlowURL,
    [Parameter(mandatory = $false)][string]$OverrideAdminDomain

)

function CheckModuleInstalled {
    param (

        [Parameter (mandatory = $true)][String]$module,
        [Parameter (mandatory = $true)][String]$moduleName
        
    )

    # Do you have module installed?
    Write-Host "`nChecking $moduleName installed..." -NoNewline

    if (Get-Module -ListAvailable -Name $module) {
    
        Write-Host " INSTALLED" -ForegroundColor Green

    }
    else {

        Write-Host " NOT INSTALLED" -ForegroundColor Red
        
        break

    }
    
}

function CheckExistingPSSession {
    param (
        [Parameter (mandatory = $true)][string]$ComputerName
    )
    
    $OpenSessions = Get-PSSession | Where-Object { $_.ComputerName -like $ComputerName -and $_.State -eq "Opened" }

    return $OpenSessions

}

function GetConfiguration {

    param (
        
        [Parameter(mandatory = $true)][String]$Command

    )

    $Output = try {
        
        Invoke-Expression $Command

    }
    catch {
        
        "FAILED"

    }

    return $Output

}

function Backup-Configuration {
    param (
        
        [Parameter(mandatory = $true)][String]$Type

    )
    
    # Run Get-CS Command for type
    Write-Host "    $Type..." -ForegroundColor "Yellow"

    # Special cases with added parameters
    switch ($Type) {
        CallQueue { $Output = GetConfiguration "Get-CS$Type -First 10000" }
        Default { $Output = GetConfiguration "Get-CS$Type" }
    } 

    if ($Output -eq "FAILED") {

        # Item Status
        $Item = @{ }
        $Item.Name = $Type
        $Item.Status = $Output

        $script:FailedItems += New-Object PSObject -Property $Item

        Write-Host "       - Failed to get configuration" -ForegroundColor Red

    }
    elseif ($Output) {

        # Save to CliXML object
        Write-Host "       - Saving $Type to $Type.xml" 
        $Output | Export-Clixml -Path "$Path\_TeamsConfigBackupTemp_\$Type.xml" -Depth 15

        # Item Count
        $Item = @{ }
        $Item.Name = $Type
        $Item.NumberOfObjects = $Output.Identity.Count
        
        $script:SavedItems += New-Object PSObject -Property $Item

        # If a CQ or AA, download custom audio .WAV files
        if ($type -eq "CallQueue") {

            $Output | ForEach-Object {

                $CallQueue = Get-CSCallQueue -Identity $_.Identity

                # Music On Hold
                if ($CallQueue.MusicOnHoldFileDownloadUri -and $CallQueue.UseDefaultMusicOnHold -eq $false) {

                    Backup-AudioFile -Id $_.Identity -AppType "CallQueue" -Uri $CallQueue.MusicOnHoldFileDownloadUri -MessageType "MusicOnHold"

                }

                # Welcome Greeting
                if ($CallQueue.WelcomeMusicFileDownloadUri) {

                    Backup-AudioFile -Id $_.Identity -AppType "CallQueue" -Uri $CallQueue.WelcomeMusicFileDownloadUri -MessageType "Greeting"

                }

            }    

        }
        elseif ($type -eq "AutoAttendant") {
            
            $Output | ForEach-Object {

                $id = $_.Identity

                $AutoAttendant = Get-CSAutoAttendant -Identity $id

                # Business Hours Welcome Greeting
                if ($AutoAttendant.DefaultCallFlow.Greetings.AudioFilePrompt.DownloadURI) {

                    $name = $AutoAttendant.DefaultCallFlow.DisplayMenu -replace " ", ""

                    Backup-AudioFile -Id $id -Scenario $name -AppType "AutoAttendant" -Uri $AutoAttendant.DefaultCallFlow.Greetings.AudioFilePrompt.DownloadURI -MessageType "Greeting"

                }

                # Business Hours Menu Prompt
                if ($AutoAttendant.DefaultCallFlow.Menu.Prompts.AudioFilePrompt.DownloadURI) {

                    $name = $AutoAttendant.DefaultCallFlow.DisplayMenu -replace " ", "" 

                    Backup-AudioFile -Id $id -Scenario $name -AppType "AutoAttendant" -Uri $AutoAttendant.DefaultCallFlow.Menu.Prompts.AudioFilePrompt.DownloadURI -MessageType "MenuPrompt"

                }

                # Other Welcome Greetings and Menus
                $AutoAttendant.CallFlows | Foreach-Object {
                    
                    $name = $_.DisplayMenu -replace " ", ""

                    # Welcome Greeting
                    if ($_.Greetings.AudioFilePrompt.DownloadUri) {

                        Backup-AudioFile -Id $id -Scenario $name -AppType "AutoAttendant" -Uri $_.Greetings.AudioFilePrompt.DownloadUri -MessageType "Greeting"

                    }

                    # Menu Prompt
                    if ($_.Menu.Prompts.AudioFilePrompt.DownloadUri) {

                        Backup-AudioFile -Id $id -Scenario $name -AppType "AutoAttendant" -Uri $_.Menu.Prompts.AudioFilePrompt.DownloadUri -MessageType "MenuPrompt"

                    }
                
                }

            }    

        }

    }
    else {

        Write-Host "        - No $Type items found!"

    }

}

function Backup-AudioFile {

    Param (

        [Parameter(mandatory = $true)][string]$Id,
        [Parameter(mandatory = $false)][string]$Scenario,
        [Parameter(mandatory = $true)][string]$AppType,
        [Parameter(mandatory = $true)][string]$MessageType,
        [Parameter(mandatory = $true)][uri]$Uri

    )

    if ($Scenario) {

        Write-Host "       - Saving $scenario $MessageType file for $AppType $id as $AppType-$id-$scenario-$MessageType.wav"
        Invoke-WebRequest -Uri $uri -OutFile "$Path\_TeamsConfigBackupTemp_\$AppType-$id-$scenario-$MessageType.wav"

    }
    else {

        Write-Host "       - Saving $MessageType file for $AppType $id as $AppType-$id-$MessageType.wav"
        Invoke-WebRequest -Uri $uri -OutFile "$Path\_TeamsConfigBackupTemp_\$AppType-$id-$MessageType.wav"

    }
 

}

function Compare-File {

    Param (

        [Parameter(mandatory = $true)][string]$File
    
    )

    # Attributes to exlude from comparison as they are likely to be different (and not of concern)
    $exclude = @("PSComputerName", "PSShowComputerName", "RunspaceId", "Status", "DisplayStatus", "DistributionListsLastExpanded", "MusicOnHoldFileDownloadUri", "WelcomeMusicFileDownloadUri", "Element", "Anchor", "Key", "DisplayAgents", "Agents")

    # Import object from file
    $backup = Import-Clixml -Path ".\_TeamsConfigBackupTemp_\$File"

    $type = $File -replace ".xml", ""

    Write-Host "`r`nComparing $type..." -ForegroundColor Yellow
    
    $backup | ForEach-Object {

        $currentId = $_.Identity
        
        $command = "Get-CS$File -Identity '$currentId'" -replace ".xml" , ""
    
        Write-Host "    - Comparing Identity: $currentId..." -NoNewline
    
        $output = GetConfiguration $command
    
        $mismatches = @()
    
        $_.PSObject.Properties | foreach-object {
            
            $name = $_.Name
            $BackupValue = [string]$_.Value
            $CurrentValue = [string]$output.$name
    
            if ($BackupValue -ne $CurrentValue) {
    
                if ($exclude -notcontains $name) {

                    $mismatch = @{ }
                    $mismatch.Name = $name
                    $mismatch.BackupValue = $BackupValue
                    $mismatch.CurrentValue = $CurrentValue
                    $mismatch.Type = $type
                    $mismatch.Identity = $currentId
        
                    $mismatches += New-Object PSObject -Property $mismatch
                    $Script:AllMismatches += New-Object PSObject -Property $mismatch

                }

            }
            
        } 
        
        if ($mismatches) {

            Write-Host " MISTMATCH" -ForegroundColor Red

            $mismatches | Format-Table -Property Type, Identity, Name, BackupValue, CurrentValue -Wrap
            

        }
        else {

            Write-Host " MATCHES" -ForegroundColor Green

        }

        

    }

}

Write-Host "`n----------------------------------------------------------------------------------------------
`n Backup-TeamsConfig.ps1 - https://www.github.com/leeford/Backup-TeamsConfig 
`n----------------------------------------------------------------------------------------------" -ForegroundColor Yellow

# Check SfB module installed
CheckModuleInstalled -module SkypeOnlineConnector -moduleName "Skype for Business Online module"

$Connected = CheckExistingPSSession -ComputerName "*admin*.online.lync.com"

if (!$Connected) {

    Write-Host "No existing Skype Online PowerShell Session..."

    if ($OverrideAdminDomain) {

        $CSSession = New-CsOnlineSession -OverrideAdminDomain $OverrideAdminDomain

    }
    else {

        $CSSession = New-CsOnlineSession

    }

    # Import Session
    Import-PSSession $CSSession -AllowClobber | Out-Null

}
else {

    Write-Host "Using existing Skype Online PowerShell Session..."

}

switch ($Action) {
    Backup {

        # Backup
        Write-Host "`r`nBacking up to $Path..."

        if ($Path -and (Test-Path $Path)) {

            # Create Temp Backup Folder
            New-Item -Path "$Path\_TeamsConfigBackupTemp_\" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

            # Start Transcript
            $date = Get-Date -UFormat "%Y-%m-%d %H%M"
            Start-Transcript -Path "$Path\_TeamsConfigBackupTemp_\transcript_$date.txt" | Out-Null

            # Items
            $script:SavedItems = @()
            $script:FailedItems = @()

            # Teams Policies

            # Get all Teams Policies
            Write-Host "`r`nBacking up Teams Policies..."

            $TeamsPolicies = Get-Command "Get-CS*Teams*Policy*"

            # Loop through
            $TeamsPolicies | ForEach-Object {

                $policy = $_.Name -replace "Get-CS", ""

                Backup-Configuration -Type $policy

            }

            # Teams Configuration

            # Get all Teams Configuration
            Write-Host "`r`nBacking up Teams Configuration..."

            $TeamsConfigs = Get-Command "Get-CS*Teams*Configuration*"

            # Loop through
            $TeamsConfigs | ForEach-Object {

                $config = $_.Name -replace "Get-CS", ""

                Backup-Configuration -Type $config

            }

            # Voice

            # Voice Routing
            Write-Host "`r`nBacking up Teams Voice Routing Configuration..."

            Backup-Configuration -Type "OnlinePSTNUsage"
            Backup-Configuration -Type "OnlineVoiceRoutingPolicy"
            Backup-Configuration -Type "OnlinePSTNGateway"
            Backup-Configuration -Type "OnlineVoiceRoute"
            Backup-Configuration -Type "TenantDialPlan"

            # Voice Apps
            Write-Host "`r`nBacking up Teams Voice Apps Configuration..."

            Backup-Configuration -Type "CallQueue"
            Backup-Configuration -Type "AutoAttendant"
            Backup-Configuration -Type "OnlineSchedule"

            # Saved Items
            if ($script:SavedItems) {
                
                Write-Host "`r`nThe following items were copied from the current configuration..." -ForegroundColor Green
                $script:SavedItems | Format-Table -Property Name, NumberOfObjects
            
            }

            # Failed Items
            if ($script:FailedItems) {

                Write-Host "`r`nThe following items were unable to be copied from the current configuration..." -ForegroundColor Red
                $script:FailedItems | Format-Table -Property Name, Status
                $failedItemStatus = "FAILED"

            }
            else {

                $failedItemStatus = "SUCCESS"

            }

            # Add Temp Backup Folder in to Zip
            $BackupFile = "$Path\TeamsConfigBackup $date.zip"

            Write-Host "`r`nAdding files to zip file $BackupFile... " -ForegroundColor Yellow -NoNewline

            Stop-Transcript | Out-Null

            # Wait for transcript to stop
            Start-Sleep -Seconds 1

            # Add all files to Zip
            $SaveBackupFile = try {
            
                Compress-Archive -Path "$Path\_TeamsConfigBackupTemp_\*" -DestinationPath $BackupFile -CompressionLevel Optimal
                Write-Host "SUCCESS" -ForegroundColor Green
                "SUCCESS"

            }
            catch {

                Write-Host "FAILED" -ForegroundColor Red
                Write-Host $SaveBackupFile -ForegroundColor Red

                "FAILED: Unable to save file as $BackupFile with error: $_"

            }

            # If posting to Flow
            if ($SendToFlowURL) {

                $Output = @{
                
                    backedUpItems        = $script:SavedItems
                    backupFileLocation   = $BackupFile
                    timestamp            = Get-Date -Format o
                    backupFileSaveStatus = $SaveBackupFile
                    backupFileSize       = [math]::Round((Get-Item $BackupFile).length / 1KB)
                    computerName         = $env:computername
                    failedItems          = $script:FailedItems
                    failedItemStatus     = $failedItemStatus

                }

                $JSON = $Output | ConvertTo-Json

                Write-Host "Sending to Flow URL: $SendToFlowURL"

                Invoke-RestMethod -Method Post -ContentType "application/json" -Body $JSON -Uri $SendToFlowURL

            }
        
        }
        else {

            Write-Warning "No path specified or path is not valid!"

        }

        # Delete Temp Backup Folder
        Remove-Item -Path "$Path\_TeamsConfigBackupTemp_\" -Force -Recurse | Out-Null

    }

    Compare {

        # Compare Backup

        Write-Host "`r`nComparing backup file to current configuration..."

        # Check File Exists
        if (Test-Path $Path) {

            # All Mismatches
            $script:AllMismatches = @()

            # Extract File
            Write-Host "Extracting $Path..."
            Expand-Archive -Path $Path -DestinationPath ".\_TeamsConfigBackupTemp_\" -Force

            # Loop through each XML file
            $files = Get-ChildItem -Path ".\_TeamsConfigBackupTemp_\*.xml"
            $files | ForEach-Object {

                Compare-File -File $_.Name

            }

            # Delete Temp Backup Folder
            Remove-Item -Path ".\_TeamsConfigBackupTemp_\" -Force -Recurse | Out-Null
    
            # If mismatches found
            if ($script:AllMismatches) {

                Write-Host "`r`nThe following MISMATCHES between the backup file and current configuration were found:" -ForegroundColor Red

                $script:AllMismatches | Format-Table -Property Type, Identity, Name, BackupValue, CurrentValue -Wrap

                # If posting to Flow
                if ($SendToFlowURL) {

                    $Output = @{
                
                        allMismatches      = $script:AllMismatches
                        backupFileLocation = $Path
                        timestamp          = Get-Date -Format o
                        computerName       = $env:computername
                        backupFileSize     = [math]::Round((Get-Item $Path).length / 1KB)
    
                    }
    
                    $JSON = $Output | ConvertTo-Json

                    Write-Host "Sending to Flow URL: $SendToFlowURL"

                    Invoke-RestMethod -Method Post -ContentType "application/json" -Body $JSON -Uri $SendToFlowURL

                }

            }
            else {

                Write-Host "`r`nNo MISMATCHES found between the backup file and current configuration." -ForegroundColor Green

            }

        }
        else {

            Write-Warning "Path specified is not valid!"

        }

    }

}
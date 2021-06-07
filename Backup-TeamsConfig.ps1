# Backup-TeamsConfig.ps1

Param (

    [Parameter(mandatory = $true)][ValidateSet('Backup', 'Compare')][string]$Action,
    [Parameter(mandatory = $false)][string]$Path,
    [Parameter(mandatory = $false)][uri]$SendToFlowURL

)

function Check-ModuleInstalled {
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

function Get-Configuration {

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
        CallQueue { $Output = Get-Configuration "Get-CS$Type -First 10000" }
        Default { $Output = Get-Configuration "Get-CS$Type" }
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
        Write-Host "       - Saving $Type to XML - $Type.xml... " -NoNewline
        try {

            $Output | Export-Clixml -Path "$Path/_TeamsConfigBackupTemp_/$Type.xml" -Depth 15
            Write-Host "SUCCESS" -ForegroundColor Green

        }
        catch {

            Write-Host "FAILED" -ForegroundColor Red

        }

        # Save to HTML page      
        # Each Item
        $Output | ForEach-Object {

            $htmlRows = $null

            # Each Property
            $_.PSObject.Properties | Sort-Object -Property Name | Foreach-Object {

                if ($script:exclude -notcontains $_.Name) {

                    $htmlRows += "<tr>
                        <th scope='row'>$($_.Name):</th>
                        <td>$($_.Value)</td>
                    </tr>"

                }
                
            }

            if ($_.Name) {
                
                $title = $_.Name

            }
            elseif ($_.Identity) {
                
                $title = $_.Identity

            }

            $htmlContent += "<div class='card'>
                    <h5 class='card-header bg-light'>$title</h5>
                    <div class='card-body'>
                        <table class='table table-borderless'>
                            <tbody>
                                $htmlRows
                            </tbody>
                        </table>
                    </div>
                </div>
                <br />"

        }

        $html = "<div class='card'>
                    <h5 class='card-header bg-light'>Overview</h5>
                    <div class='card-body'>
                        <table class='table table-borderless'>
                            <tbody>
                                <tr>
                                    <th scope='row'>Backup Taken:</th>
                                    <td>$date</td>
                                </tr>
                                <tr>
                                    <th scope='row'>Number of Items:</th>
                                    <td>$($Output.Identity.Count)</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
                <br />
                $htmlContent"
                
        Write-Host "       - Saving $Type to HTML - $Type.htm... " -NoNewline
        Create-HTMLPage -Content $html -PageTitle "$Type" -Path "$Path/_TeamsConfigBackupTemp_/HTML/$Type.htm"

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

    try {

        if ($Scenario) {

            Write-Host "       - Saving $scenario $MessageType file for $AppType $id as $AppType-$id-$scenario-$MessageType.wav... " -NoNewline
            Invoke-WebRequest -Uri $uri -OutFile "$Path/_TeamsConfigBackupTemp_/AudioFiles/$AppType-$id-$scenario-$MessageType.wav"
    
        }
        else {
    
            Write-Host "       - Saving $MessageType file for $AppType $id as $AppType-$id-$MessageType.wav... " -NoNewline
            Invoke-WebRequest -Uri $uri -OutFile "$Path/_TeamsConfigBackupTemp_/AudioFiles/$AppType-$id-$MessageType.wav"
    
        }

        Write-Host "SUCCESS" -ForegroundColor Green

    }
    catch {

        Write-Host "FAILED" -ForegroundColor Red

    }

}

function Compare-File {

    Param (

        [Parameter(mandatory = $true)][string]$File
    
    )

    # Import object from file
    $backup = Import-Clixml -Path "./_TeamsConfigBackupTemp_/$File"

    $type = $File -replace ".xml", ""

    Write-Host "`r`nComparing $type..." -ForegroundColor Yellow
    
    $backup | ForEach-Object {

        $currentId = $_.Identity
        
        $command = "Get-CS$File -Identity '$currentId'" -replace ".xml" , ""
    
        Write-Host "    - Comparing Identity: $currentId..." -NoNewline
    
        $output = Get-Configuration $command
    
        $mismatches = @()
    
        $_.PSObject.Properties | Foreach-Object {
            
            $name = $_.Name
            $BackupValue = [string]$_.Value
            $CurrentValue = [string]$output.$name
    
            if ($BackupValue -ne $CurrentValue) {
    
                if ($script:exclude -notcontains $name) {

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

function Create-HTMLPage {
    param (

        [Parameter(mandatory = $true)][string]$Content,
        [Parameter(mandatory = $true)][string]$PageTitle,
        [Parameter(mandatory = $true)][string]$Path

    )

    $html = "
    <div class='p-0 m-0' style='background-color: #F3F2F1'>
        <div class='container m-3'>
            <div class='page-header'>
                <h1>$pageTitle</h1>
                <h5>Created with <a href='https://www.lee-ford.co.uk/backup-teamsconfig'>Backup-TeamsConfig</a></h5>
            </div>

            $Content

            </div>
    </div>"

    try {

        ConvertTo-Html -CssUri "https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" -Body $html -Title $PageTitle | Out-File $Path -Encoding "utf8"
        Write-Host "SUCCESS" -ForegroundColor Green

    }
    catch {

        Write-Host "FAILED" -ForegroundColor Red
        Write-Host $_.Exception -ForegroundColor Red

    }

}

function Check-ExistingPSSession {
    param (
        [Parameter (mandatory = $true)][string]$ComputerName
    )
    
    $OpenSessions = Get-PSSession | Where-Object { $_.ComputerName -like $ComputerName -and $_.State -eq "Opened" }

    return $OpenSessions

}

# Attributes to exlude from comparisons and HTML reports as they are likely to be different (and not of concern)
$script:exclude = @("PSComputerName", "PSShowComputerName", "RunspaceId", "Status", "DisplayStatus", "DistributionListsLastExpanded", "MusicOnHoldFileDownloadUri", "WelcomeMusicFileDownloadUri", "Element", "Anchor", "Key", "DisplayAgents", "Agents")

Write-Host "`n----------------------------------------------------------------------------------------------
`n Backup-TeamsConfig.ps1 - https://www.lee-ford.co.uk/backup-teamsconfig
`n----------------------------------------------------------------------------------------------" -ForegroundColor Yellow

# Check Teams module installed
Check-ModuleInstalled -module MicrosoftTeams -moduleName "Microsoft Teams module"

$Connected = Check-ExistingPSSession -ComputerName "api.interfaces.records.teams.microsoft.com"

if (!$Connected) {

    Write-Host "No existing PowerShell Session..."

    Connect-MicrosoftTeams

}
else {

    Write-Host "Using existing PowerShell Session..."

}

switch ($Action) {
    Backup {

        # Backup
        Write-Host "`r`nBacking up to $Path..."

        if ($Path -and (Test-Path $Path)) {

            # Create Temp Backup Folders
            New-Item -Path "$Path/_TeamsConfigBackupTemp_/" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            New-Item -Path "$Path/_TeamsConfigBackupTemp_/HTML/" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            New-Item -Path "$Path/_TeamsConfigBackupTemp_/AudioFiles/" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

            # Start Transcript
            $date = Get-Date -UFormat "%Y-%m-%d %H%M"
            Start-Transcript -Path "$Path/_TeamsConfigBackupTemp_/transcript_$date.txt" | Out-Null

            # Items
            $script:SavedItems = @()
            $script:FailedItems = @()

            # Teams Policies
            Write-Host "`r`nBacking up Teams Policies..."
            Get-Command "Get-CS*Teams*Policy*" | ForEach-Object {

                $policy = $_.Name -replace "Get-CS", ""
                Backup-Configuration -Type $policy

            }

            # Teams Configuration
            Write-Host "`r`nBacking up Teams Configuration..."
            Get-Command "Get-CS*Teams*Configuration*" | ForEach-Object {

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

            # Voice Apps
            Write-Host "`r`nBacking up Teams Voice Apps Configuration..."

            Backup-Configuration -Type "CallQueue"
            Backup-Configuration -Type "AutoAttendant"
            Backup-Configuration -Type "OnlineSchedule"

            # Misc
            Write-Host "`r`nBacking up misc Tenant Configuration..."
            Get-Command "Get-CSTenant*" | ForEach-Object {

                $config = $_.Name -replace "Get-CS", ""
                Backup-Configuration -Type $config

            }

            # Saved Items
            if ($script:SavedItems) {
                
                Write-Host "`r`nThe following items were copied from the current configuration..." -ForegroundColor Green
                $script:SavedItems | Format-Table -Property Name, NumberOfObjects

            }

            # Failed Items
            if ($script:FailedItems) {

                Write-Host "`r`nThe following items were unable to be copied from the current configuration..." -ForegroundColor Red
                $script:FailedItems | Format-Table -Property Name, Status
                $backupStatus = "FAILED"

            }
            else {

                $backupStatus = "SUCCESS"

            }

            # HTML Report
            $script:SavedItems | Sort-Object -Property Name | Foreach-Object {
    
                $htmlSuccessfulRows += "<tr>
                            <td><a href='./HTML/$($_.name).htm'>$($_.Name)</a></td>
                            <td>$($_.NumberOfObjects)</td>
                        </tr>"

            }

            $script:FailedItems | Sort-Object -Property Name | Foreach-Object {
    
                $htmlFailedRows += "<tr>
                            <td><a href='./HTML/$($_.name).htm'>$($_.Name)</a></td>
                            <td>$($_.NumberOfObjects)</td>
                        </tr>"

            }

            $html = "<div class='card'>
                        <h5 class='card-header bg-light'>Overview</h5>
                        <div class='card-body'>
                            <table class='table table-borderless'>
                                <tbody>
                                    <tr>
                                        <th scope='row'>Backup Taken:</th>
                                        <td>$date</td>
                                    </tr>
                                    <tr>
                                        <th scope='row'>Backup Status:</th>
                                        <td>$backupStatus</td>
                                    </tr>
                                    <tr>
                                        <th scope='row'>Number of Successful (Saved) Item Types:</th>
                                        <td>$($script:SavedItems.Count)</td>
                                    </tr>
                                    <tr>
                                        <th scope='row'>Number of Failed (Not-Saved) Item Types:</th>
                                        <td>$($script:FailedItems.Count)</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <br />
                    <div class='card'>
                        <h5 class='card-header bg-light'>Successful (Saved) Items</h5>
                        <div class='card-body'>
                            <table class='table table-borderless'>
                                <thead>
                                    <tr>
                                        <th scope='col'>Type</th>
                                        <th scope='col'>Number of Items</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    $htmlSuccessfulRows
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <br />
                    <div class='card'>
                        <h5 class='card-header bg-light'>Failed (Not-Saved) Items</h5>
                        <div class='card-body'>
                            <table class='table table-borderless'>
                                <thead>
                                    <tr>
                                        <th scope='col'>Type</th>
                                        <th scope='col'>Number of Items</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    $htmlFailedRows
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <br />"
        
            Write-Host " - Saving Backup Report to HTML - Report.htm... " -NoNewline
            Create-HTMLPage -Content $html -PageTitle "Backup Report" -Path "$Path/_TeamsConfigBackupTemp_/Report.htm"

            # Add Temp Backup Folder in to Zip
            $BackupFile = "$Path/TeamsConfigBackup $date.zip"

            Write-Host "`r`nAdding files to zip file $BackupFile... " -ForegroundColor Yellow -NoNewline

            Stop-Transcript | Out-Null

            # Wait for transcript to stop
            Start-Sleep -Seconds 1

            # Add all files to Zip
            $SaveBackupFile = try {
            
                Compress-Archive -Path "$Path/_TeamsConfigBackupTemp_/*" -DestinationPath $BackupFile -CompressionLevel Optimal
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
                    failedItemStatus     = $backupStatus

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
        Remove-Item -Path "$Path/_TeamsConfigBackupTemp_/" -Force -Recurse | Out-Null

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
            Expand-Archive -Path $Path -DestinationPath "./_TeamsConfigBackupTemp_/" -Force

            # Loop through each XML file
            $files = Get-ChildItem -Path "./_TeamsConfigBackupTemp_/*.xml"
            $files | ForEach-Object {

                Compare-File -File $_.Name

            }

            # Delete Temp Backup Folder
            Remove-Item -Path "./_TeamsConfigBackupTemp_/" -Force -Recurse | Out-Null
    
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
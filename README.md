# Backup-TeamsConfig

_**Disclaimer:** This script is provided ‘as-is’ without any warranty or support. Use of this script is at your own risk and I accept no responsibility for any damage caused._

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/example-running.png)

## Introduction ##
Backup-TeamsConfig is a PowerShell script allowing you to backup various parts of Microsoft Teams configuration and package it up in to a single file for safe keeping - this includes policies, configurations and voice applications (inc. audio files).

### Why? - Doesn't Microsoft already keep copies of this? ###
I'm sure they do. However it doesn't hurt to have a copy should the unthinkable happen!

Another reason for backing up is it is a way of having a "snapshot" of the configuration at a point in time. With this you can look back and compare it to the existing configuration (this script will do this for you if required). If undocumented changes have taken place (it could be hard to spot without a back up to look back on).

### What does it backup? ###

Currently the script makes a copy of the following:

| Item                               | Examples                                           |
| ---------------------------------- | ----------------------------------------------- |
| Get-Teams\*Policy           | Get-TeamsAppPermissionPolicy, Get-TeamsMessagingPolicy 
| Get-CSTeams\*Configuration          | Get-TeamsMeetingConfiguration, Get-TeamsClientConfiguration    
| Get-CSTenant\* | Get-CSTenant, Get-CSTenantNetworkSite |
| Voice Routing | Get-CSOnlinePSTNUsage, Get-CSOnlineVoiceRoute |
| Call Queues                          | Configuration, music on hold and greetings |
| Auto Attendants                      | Configuration, menu prompts, greetings and schedule   |

> Note: The script will backup Teams policies or configuration by using a wildcard. If a new type of policy or configuration appears e.g. "Get-CSTeamsExamplePolicy" it will automatically get included within the backup.

## Usage ##

> Before you can use this tool you need to ensure you have the Microsoft Teams PowerShell module installed - <https://docs.microsoft.com/en-us/microsoftteams/teams-powershell-install>

To get started download the latest release from [GitHub](https://github.com/leeford/Backup-TeamsConfig/releases)

**Create a Backup** - Provide a path (folder) to save the backup file to:

```.\Backup-TeamsConfig.ps1 -Action Backup -Path C:\backup```

The script will backup each item and put everything in to a timestamped zip file:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/backup-example.png)


**Compare a Backup** - Provide a path (existing backup file) to compare with current configuration:

```.\Backup-TeamsConfig.ps1 -Action Compare -Path C:\<backupfile.zip>```

The script will go through each item within the backup and compare it against the existing configuration, noting any mismatches:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/compare-example.png)

**View a Backup**
Once a backup has successfully completed, you can extract the .zip file and view the contents.

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/view-backup.png)

Included in a backup:

- HTML Reports - Open Report.htm and view the status of the backup and associated backed up items
  ![](https://www.lee-ford.co.uk/images/backup-teamsconfig/backup-report.gif)
- CLIXML Files - Raw CLIXML files captured that include ALL settings. These are used when comparing backup files to current configuration
- Audio Files - Recordings attached to Call Queues and Auto Attendants

**Create a Backup and Post Results to Flow** - Provide a path (folder) to save the backup file to and a URL in Flow to post to:

```.\Backup-TeamsConfig.ps1 -Action Backup -Path C:\backup -SendToFlowURL "<FlowURL>"```

The Flow URL can be found when creating and saving a "When a HTTP request is received" trigger:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/flow-url-example.png)

The example Flow "BackupTeamsConfig(Report)Flow.zip" found with the script can be imported in to Flow to illustrate how this can be used (in this case send an email)

_Success:_

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/success-email-example.png)

_Failed:_

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/failed-email-example.png)

**Compare a Backup and Post Results to Flow** - Provide a path (existing backup file) to compare with current configuration and a URL in Flow to post to:

```.\Backup-TeamsConfig.ps1 -Action Compare -Path C:\<backupfile.zip> -SendToFlowURL "<FlowURL>"```

The example Flow "BackupTeamsConfig(Comparison)Flow.zip" found with the script can be imported in to Flow to illustrate how this can be used (in this case send an email):

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/compare-email-example.png)

## Known Issues ##
- Comparison of certain attributes in Voice Apps are not compared (as the backup and current never match properly). I am looking to resolve this.
- HTML reports with nested configuration will not show correctly in tables. For example, the "CallFlows" of an Auto Attendant will show as a the string value of the Object "Microsoft.Rtc.Management.Hosted.OAA.Models.CallFlow" rather than the configuration.

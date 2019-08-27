# Backup-TeamsConfig

_**Disclaimer:** This script is provided ‘as-is’ without any warranty or support. Use of this script is at your own risk and I accept no responsibility for any damage caused._

## Introduction ##
Backup-TeamsConfig is a PowerShell script allowing you to backup various parts of Microsoft Teams configuration and package it up in to a single file for safe keeping - this includes policies, configurations and voice applications (inc. audio files).

### Why? - Doesn't Microsoft already keep copies of this? ###
I'm sure they do. However it doesn't hurt to have a copy should the unthinkable happen!

Another reason for backing up is it is a way of having a "snapshot" of the configuration at a point in time. With this you can look back and compare it to the existing configuration (this script will do this for you if required). If undocumented changes have taken place (it could be hard to spot without a back up to look back on)

### What does it backup? ###

Currently the script backs up the following:

| Item                               | Notes                                           |
| ---------------------------------- | ----------------------------------------------- |
| TeamsAppPermissionPolicy           |
| TeamsAppSetupPolicy                |
| TeamsCallingPolicy                 |
| TeamsCallParkPolicy                |
| TeamsChannelsPolicy                |
| TeamsComplianceRecordingPolicy     |
| TeamsEducationAssignmentsAppPolicy |
| TeamsEmergencyCallingPolicy        |
| TeamsEmergencyCallRoutingPolicy    |
| TeamsFeedbackPolicy                |
| TeamsMeetingBroadcastPolicy        |
| TeamsMeetingPolicy                 |
| TeamsMessagingPolicy               |
| TeamsAppPermissionPolicy           |
| TeamsAppSetupPolicy                |
| TeamsCallingPolicy                 |
| TeamsCallParkPolicy                |
| TeamsChannelsPolicy                |
| TeamsComplianceRecordingPolicy     |
| TeamsEducationAssignmentsAppPolicy |
| TeamsEmergencyCallingPolicy        |
| TeamsEmergencyCallRoutingPolicy    |
| TeamsFeedbackPolicy                |
| TeamsMeetingBroadcastPolicy        |
| TeamsMeetingPolicy                 |
| TeamsMessagingPolicy               |
| TeamsNotificationAndFeedsPolicy    |
| TeamsUpgradePolicy                 |
| TeamsVideoInteropServicePolicy     |
| TeamsClientConfiguration           |
| TeamsGuestCallingConfiguration     |
| TeamsGuestMeetingConfiguration     |
| TeamsGuestMessagingConfiguration   |
| TeamsMeetingBroadcastConfiguration |
| TeamsMeetingConfiguration          |
| TeamsMigrationConfiguration        |
| TeamsUpgradeConfiguration          |
| OnlinePSTNUsage                    |
| OnlineVoiceRoutingPolicy           |
| OnlinePSTNGateway                  |
| OnlineVoiceRoute                   |
| TenantDialPlan                     |
| CallQueue                          | Includes Music on Hold and Greeting audio files |
| AutoAttendant                      | Includes Menu Prompt and Greeting audio files   |
| OnlineSchedule (for AutoAttendant) |



> Note: The script will backup any Teams policy or configuration by using a wildcard. If a new type of policy or configuration appears e.g. "Get-CSTeamsExamplePolicy" it will automatically get included within the backup.

## Usage ##

> Before you can use this tool you need to ensure you have the Skype Online PowerShell module installed - https://www.microsoft.com/en-us/download/details.aspx?id=39366

To get started download the latest release from [GitHub](https://github.com/leeford/Backup-TeamsConfig/releases)

**Take a Backup** - Provide a path (folder) to save the backup file to:

```.\Backup-TeamsConfig.ps1 -Action Backup -Path C:\backup```

The script will backup each item and put everything in to a dated zip file:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/backup-example.png)

If you look inside the zip file you can see each item:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/zip-file-example.png)

**Compare a Backup** - Provide a path (existing backup file) to compare with current configuration:

```.\Backup-TeamsConfig.ps1 -Action Compare -Path C:\<backupfile.zip>```

The script will go through each item within the backup and compare it against the existing configuration, noting any mismatches:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/compare-example.png)

**Take a Backup and Post Results to Flow** - Provide a path (folder) to save the backup file to and a URL in Flow to post to:

```.\Backup-TeamsConfig.ps1 -Action Backup -Path C:\backup -SendToFlowURL "<FlowURL>"```

The Flow URL can be found when creating and saving a "When a HTTP request is received" trigger:

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/compare-example.png)

The example Flow "BackupTeamsConfig(Report)Flow.zip" found with the script can be imported in to Flow to illustrate how this can be used (in this case send an email)

Successful:
![](https://www.lee-ford.co.uk/images/backup-teamsconfig/success-email-example.png)

Failure:
![](https://www.lee-ford.co.uk/images/backup-teamsconfig/failed-email-example.png)

**Compare a Backup and Post Results to Flow** - Provide a path (existing backup file) to compare with current configuration and a URL in Flow to post to:

```.\Backup-TeamsConfig.ps1 -Action Compare -Path C:\<backupfile.zip> -SendToFlowURL "<FlowURL>"```

The example Flow "BackupTeamsConfig(Comparison)Flow.zip" found with the script can be imported in to Flow to illustrate how this can be used (in this case send an email):

![](https://www.lee-ford.co.uk/images/backup-teamsconfig/compare-email-example.png)

## Known Issues ##
- Comparison of certain attributes in Voice Apps are not compared (as the backup and current never match properly). I am looking to resolve this.


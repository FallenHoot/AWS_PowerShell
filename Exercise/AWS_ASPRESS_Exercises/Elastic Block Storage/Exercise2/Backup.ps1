
#This script will create a snapshot of all volumes in the account and keep them for a specified period  

param(
    [parameter(mandatory=$false)][string]$Type = 'Daily',
    [parameter(mandatory=$false)][string]$RetentionDays = 14
)

Function CreateBackup($type)
{

    #First, find any new volumes that have not been marked for backup
    Get-EC2Volume | ForEach-Object {
        $HasKey = $False
        $_.Tag | ForEach-Object { If ($_.Key -eq 'BackupEnabled') { $HasKey = $True } } 
        If($HasKey -eq $False) {
            #Add Tag to this volume
            $VolumeId = $_.VolumeId
            $Tag = New-Object amazon.EC2.Model.Tag
            $Tag.Key='BackupEnabled'
            $Tag.Value='True'
            Write-Host "Found new volume: $VolumeId"
            New-EC2Tag -ResourceId $VolumeId -Tag $Tag
        }
    }
        
    
    $Filter = New-Object Amazon.EC2.Model.Filter
    $Filter.Name = 'tag:BackupEnabled'
    $Filter.Value = 'True'
    Get-EC2Volume -Filter $Filter | ForEach-Object { 
        $Description = ""
        
        #If this volume is attached to an instance, let's record the information in the comments
        if($_.Attachment){
            $Device = $_.Attachment[0].Device
            $InstanceId = $_.Attachment[0].InstanceId
            $Reservation = Get-EC2Instance $InstanceId
            $Instance = $Reservation.RunningInstance | Where-Object {$_.InstanceId -eq $InstanceId}
            $Name = ($Instance.Tag | Where-Object { $_.Key -eq 'Name' }).Value
            $Description = "Currently attached to $Name as $Device;"
        }
        
        #Create the backup
        $Volume = $_.VolumeId
	    Write-Host "Creating snapshot of volume: $Volume; $Description"
        $Snapshot = New-EC2Snapshot $Volume -Description "$Type backup of volume $Volume; $Description" 

        #Add a tag so we can distinguish this snapshot from all the others
        $Tag = New-Object amazon.EC2.Model.Tag
        $Tag.Key='BackupType'
        $Tag.Value=$Type
        New-EC2Tag -ResourceId $Snapshot.SnapshotID -Tag $Tag
    }
}

Function PurgeBackups($Type, $RetentionDays)
{
    #Delete and snapshots created by this tool, that are older than the specified number of days
    $Filter = New-Object Amazon.EC2.Model.Filter
    $Filter.Name = 'tag:BackupType'
    $Filter.Value = $Type
    $RetentionDate = ([DateTime]::Now).AddDays(-$RetentionDays)
    Get-EC2Snapshot -Filter $filter | Where-Object { [datetime]::Parse($_.StartTime) -lt $RetentionDate} | ForEach-Object {
        $SnapshotId = $_.SnapshotId
        Write-Host "Removing snapshot: $SnapshotId"
        Remove-EC2Snapshot -SnapshotId $SnapshotId -Force
    }
}

  
CreateBackup $Type
PurgeBackups $Type $RetentionDays

Function CheckPath(){

$Global:Path = Read-Host "Enter CSV Folder Path"
$Global:Path = "C:\Jedi\logs\"
if((Test-Path $Global:Path) -match 'False'){
        Write-Host "Log folder doesn't exist, creating: $Global:Path"
        New-Item -Type directory $Global:Path  | Out-Null
    }
}


Function GetInstanceList($region){
Write-Host "Writing to Log folder: C:\ops\logs\instances"
    $instances = (Get-ec2instance -region $region).Instances

    $date=$(get-date -format "MMddyyyy-hhmmtt").ToString()
    $reg=$region.ToString()
    $FilePath=$Global:Path +$region+"-"+$date+".csv"
    $FilePath=$FilePath.ToString()

    $header="Name,InstanceID,PrivateIP,PublicIP,Status,Volumes" | Out-file -FilePath $FilePath -Append


    foreach ($instance in $instances) {
        $BlockDeviceMappings=$instance.BlockDeviceMappings
        $VolumeID=foreach($volume in $BlockDeviceMappings){$volume.Ebs.VolumeId+";"}
        $InstanceStatus=$instance.State.Name
        $InstanceId=$instance.InstanceId
        $InstancePrivateIP=$instance.PrivateIpAddress
        $InstancePublicIP=$instance.PublicIpAddress
        $tags = $instance | Where-Object {$_.instanceId -eq $InstanceId} |select Tag
        $ServerName = $tags.Tag | Where-Object {$_.Key -eq "Name"} | select -ExpandProperty Value

        $info=$ServerName+","+$InstanceId+","+$InstancePrivateIP+","+$InstancePublicIP+","+$InstanceStatus+","+$VolumeID | Out-File -FilePath $FilePath -Append
        }
}


Checkpath
ClearLogs
$Region = Get-EC2Region | Sort-Object RegionName
foreach ($RegionName in ($Region.RegionName)) {
GetInstanceList -region "$RegionName"
}

#Pre-defined Loging
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Global:Logfile -value $logstring
}

# Login to AWS Subscription
Function Login_to_AWS {
If ( (Get-ExecutionPolicy) -ne "RemoteSigned")
{
set-ExecutionPolicy RemoteSigned -Scope Process -Force
}


If (!(Import-Module AWSPowerShell)){ Import-Module AWSPowerShell }

#Set-AWSCredential -AccessKey ###### -SecretKey ###### -StoreAs NAME
Initialize-AWSDefaults -ProfileName ECS_Zach
Get-AWSCredential -ListProfileDetail
$Global:LocalPC_ExteralIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
}

#Pick AWS Region
Function AWSRegion{
# Select a AWS Region of choice
$Global:RegionArray = (Get-EC2Region)
$Global:Region = $Global:RegionArray | Select-Object RegionName | Out-GridView -PassThru
Set-DefaultAWSRegion -Region $Global:Region.RegionName
}

#Add EC2 Tags
Function Add-EC2Tag 
{

Param (
      [string][Parameter(Mandatory=$True)]$key,
      [string][Parameter(Mandatory=$True)]$value,
      [string][Parameter(Mandatory=$True)]$resourceId
      )

    $Tag = New-Object amazon.EC2.Model.Tag
    $Tag.Key = $Key
    $Tag.Value = $value

    New-EC2Tag -ResourceId $resourceId -Tag $Tag | Out-Null
}

# Create new VPC -- 14.1
Function createVPC{
$vpcResult = New-EC2Vpc -CidrBlock "192.168.0.0/16" -InstanceTenancy default
$Global:vpcId = $vpcResult.VpcId

Add-EC2Tag -key Name -value $Global:VPCTag -resourceId $Global:vpcId
}

# Enable DNS Support & Hostnames in VPC
Function enableDNS{
Edit-EC2VpcAttribute -VpcId $Global:vpcId -EnableDnsSupport $true
Edit-EC2VpcAttribute -VpcId $Global:vpcId -EnableDnsHostnames $true
}

#Create EIP Address
Function CreateEIP{
$eipResult = New-EC2Address -Domain $Global:vpcId
$Global:eipId = $eipResult.AllocationId
$Global:eIP = $eipResult.PublicIp
}

# Private Subnet
Function createPrivateSubnet{
$Global:PVS1AZ = $Global:Region.RegionName + "a"
$pvs1aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "192.168.2.0/24" -AvailabilityZone "$Global:PVS1AZ"
$Global:pvs1aId = $pvs1aResult.SubnetId
Add-EC2Tag -key Name -value $Global:pvs1Tag -resourceId $Global:pvs1aId
 }

Function createEC2Security1 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:securityGroupIdTag;
    GroupDescription = "Load balancer security group"
}
$IP = "0.0.0.0/0"
$Global:securityGroupId = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges=$IP}
$ip2 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges="0.0.0.0/0"}
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="tcp"; FromPort="943"; ToPort="943"; IpRanges="0.0.0.0/0"}
$ip5 = @{ IpProtocol="udp"; FromPort="1194"; ToPort="1194"; IpRanges="0.0.0.0/0"}


Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroupId -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5)
($Global:securityGroupId | Get-EC2SecurityGroup).IpPermissions  
Add-EC2Tag -key Name -value $Global:securityGroupIdTag -resourceId $Global:securityGroupId
}

# Create KeyPair
Function createKeyPair {
#create a KeyPair, this is used to encrypt the Administrator password.
$keypair = New-EC2KeyPair -KeyName $Global:KeyPairName
"$($keypair.KeyMaterial)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem"
"KeyName: $($keypair.KeyName)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
"KeyFingerprint: $($keypair.KeyFingerprint)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
}
 
Function PrivateDBServer {
$userdata = @"
#!/bin/bash
sudo apt-get update
sudo apt-get install openvpn easy-rsa
make-cadir ~/openvpn-ca
"@

$PIA = Get-ec2subnet -SubnetId $Global:pvs1aId
$IP = $PIA.CidrBlock.Substring(0,$PIA.CidrBlock.Length-4)

$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            ImageId = $Global:ImageID
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroupId
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pvs1aId
			PrivateIpAddress = $IP  + "5"
			#AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:PrivateDBServer = New-EC2Instance @parameters
($Global:PrivateDBServer.Instances).InstanceID
Add-EC2Tag -key Name -value $Global:PrivateServerTag -resourceId ($Global:PrivateDBServer.Instances).InstanceID
}

 
 Function LOG {
LogWrite "Get-Date"
LogWrite
}

Function Build_Exercise {
Login_to_AWS
AWSRegion
Variables
createVPC
enableDNS
CreateEIP
Start-Sleep -Seconds 5
createPrivateRouteTable
createPrivateSubnet
createEC2Security1
createKeyPair
PrivateDBServer
LOG
AWS_Menu
}

Function Variables {
$Tag = $Global:Region.RegionName + "-openVPN"

$LogDate = Get-Date -UFormat "%y%h%Y_%H%M"
$Global:Outpath  = "C:\Jedi\PowerShell\Exercise"
$Global:Logfile = "C:\Jedi\PowerShell\Exercise\$LogDate" + "$Tag" + "_Exercise.log"

$Global:ImageID = ((Get-EC2Image -Region $Global:Region.RegionName -Filter @{"Name"="name";"Value"="*OpenVPN Access Server*"} | sort -Property CreationDate -Descending)[0]).imageid

$Global:KeyPairName = $Tag
$Global:VPCTag = $Tag + "-VPC"
$Global:rtTag = $Tag + "-Main Route Table"
$Global:rtpvtTag = $Tag + "-Private Route Table"
$Global:pvs1Tag = $Tag + "-Private Subnet"
$Global:securityGroupIdTag  = $Tag + "-SG"
$Global:PrivateServerTag = $Tag + "-Server"

}

Function AWS_Menu {
# Menu TUI
Write-Host "`n AWS Menu:" -Fore Cyan
[int]$global:Menu = 0
while ( $global:Menu -lt 1 -or $global:Menu -gt 3 ){
Write-host "1. Create Exercise" -Fore Cyan
Write-host "2. Delete Exercise" -Fore Cyan
Write-host "3. Exit" -Fore Cyan
[Int]$global:Menu = read-host "Choose an option 1 to 3" }
Switch( $global:Menu ){
1{Build_Exercise}
2{Delete_Exercise}
3{Exit}
}
}
AWS_Menu
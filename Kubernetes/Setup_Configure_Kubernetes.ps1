<# Description: 'Kubernetes AWS PowerShell Template: 

Create a Kubernetes cluster in a new VPC. The master node is an auto-recovering Amazon EC2
  instance. 1-20 additional EC2 instances in an AutoScalingGroup join the
  Kubernetes cluster as nodes. An ELB provides configurable external access
  to the Kubernetes API. The new VPC includes a bastion host to grant
  SSH access to the private subnet for the cluster. This template creates
  two stacks: one for the new VPC and one for the cluster. The stack is
  suitable for development and small single-team clusters. **WARNING** This
  template creates four Amazon EC2 instances with default settings. You will
  be billed for the AWS resources used if you create a stack from this template.
 #>

#Pre-defined Loging
Function LogWrite {
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
#If (!(Import-Module SSMDevOps)){ Import-Module SSMDevOps }

#Set-AWSCredential -AccessKey ###### -SecretKey ###### -StoreAs ECS_Zach
Initialize-AWSDefaults -ProfileName ECS_Zach
Get-AWSCredential -ListProfileDetail

#Collect Exteral IP
$Global:LocalPC_ExteralIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
}

#Pick AWS Region
Function AWSRegion {
# Select a AWS Region of choice
$Global:RegionArray = (Get-EC2Region)
$Global:Region = $Global:RegionArray | Select-Object RegionName | Out-GridView -PassThru
Set-DefaultAWSRegion -Region $Global:Region.RegionName
}

#Add EC2 Tags
Function Add-EC2Tag {

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

# Create new VPC --
Function createVPC {
$vpcResult = New-EC2Vpc -CidrBlock "10.0.0.0/16" -InstanceTenancy default
$Global:vpcId = $vpcResult.VpcId

Add-EC2Tag -key Name -value $Global:VPCTag -resourceId $Global:vpcId
}

# Enable DNS Support & Hostnames in VPC
Function enableDNS {
Edit-EC2VpcAttribute -VpcId $Global:vpcId -EnableDnsSupport $true
Edit-EC2VpcAttribute -VpcId $Global:vpcId -EnableDnsHostnames $true
}

# Create new Internet Gateway
Function createGateway {
$igwResult = New-EC2InternetGateway
$Global:igwAId = $igwResult.InternetGatewayId
Add-EC2Tag -key Name -value $Global:igwTag -resourceId $Global:igwAId
Add-EC2InternetGateway -InternetGatewayId $Global:igwAId -VpcId $Global:vpcId
}

# Create new Public Route Table
Function createRouteTable {
$rtResultA = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtPublicID = $rtResultA.RouteTableId
Add-EC2Tag -key Name -value $Global:rtTag -resourceId $Global:rtPublicID
Start-Sleep 4
$rResult = New-EC2Route -RouteTableId $Global:rtPublicID -GatewayId $Global:igwAId -DestinationCidrBlock '0.0.0.0/0'
Add-EC2Tag -key Network -value "Public" -resourceId $Global:rtPublicID
}

# Public Subnets
Function createPublicSubnet1B {
$Global:PS1AZ = $Global:Region.RegionName + "a"
$pus1BResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "10.0.128.0/19" -AvailabilityZone "$Global:PS1AZ"
$Global:pus1bId = $pus1BResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPublicID -SubnetId $Global:pus1bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus1bId
Add-EC2Tag -key Network -value "Public" -resourceId $Global:pvs1aId
Add-EC2Tag -key Network -value "KubernetesCluster" -resourceId $Global:pvs1aId

}

#Create EIP Address
Function CreateEIP {
$eipResult = New-EC2Address -Domain $Global:vpcId
$Global:eipId = $eipResult.AllocationId
$Global:eIP = $eipResult.PublicIp
}

#Create NAT Gateway
Function CreateNATGateway {
$ntgResult = New-EC2NatGateway -SubnetId $Global:pus1bId -AllocationId $Global:eipId
$ntgId = Get-EC2NatGateway | Where-Object {$_.VpcId -eq $Global:vpcId}
$Global:ntgId = $ntgId.NatGatewayId
Add-EC2Tag -key Name -value $Global:ntgTag -resourceId $Global:ntgId
}
 
 #Create Private Route Table
Function createPrivateRouteTable { 
$rtResultPvt = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtPrivateID = $rtResultPvt.RouteTableId
Add-EC2Tag -key Name -value $Global:rtpvtTag -resourceId $Global:rtPrivateID
$rpvtResult = New-EC2Route -RouteTableId $Global:rtPrivateID -NatGatewayId $Global:ntgId -DestinationCidrBlock '0.0.0.0/0'
Add-EC2Tag -key Network -value "Private" -resourceId $Global:rtPrivateID

 }
 
# Private Subnets
Function createPrivateSubnet {
$Global:PVS1AZ = $Global:Region.RegionName + "a"
$pvs1aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "10..0.0.0/19" -AvailabilityZone "$Global:PVS1AZ"
$Global:pvs1aId = $pvs1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPrivateID -SubnetId $Global:pvs1aId
Add-EC2Tag -key Name -value $Global:pvs1Tag -resourceId $Global:pvs1aId
Add-EC2Tag -key Network -value "Private" -resourceId $Global:pvs1aId
 }

Function createBastionSecurityGroup {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:BastionSecurityGroupIdTag;
    GroupDescription = "Load balancer security group"
}
$IP = "0.0.0.0/0"
$Global:BastionSecurityGroupId = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges=$IP}

Grant-EC2SecurityGroupIngress -GroupId $Global:BastionSecurityGroupId -IpPermission @( $ip1 )
($Global:BastionSecurityGroupId | Get-EC2SecurityGroup).IpPermissions  
Add-EC2Tag -key Name -value $Global:BastionSecurityGroupIdTag -resourceId $Global:BastionSecurityGroupId
}

# Create KeyPair
Function createKeyPair {
#create a KeyPair, this is used to encrypt the Administrator password.
$keypair = New-EC2KeyPair -KeyName $Global:KeyPairName
"$($keypair.KeyMaterial)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem"
"KeyName: $($keypair.KeyName)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
"KeyFingerprint: $($keypair.KeyFingerprint)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
}

Function BastionServer {
$userdata = @"
#!/bin/bash
BASTION_BOOTSTRAP_FILE=bastion_bootstrap.sh
BASTION_BOOTSTRAP=https://s3.amazonaws.com/quickstart-reference/linux/bastion/latest/scripts/bastion_bootstrap.sh
curl -s -o $BASTION_BOOTSTRAP_FILE $BASTION_BOOTSTRAP
chmod +x $BASTION_BOOTSTRAP_FILE
./$BASTION_BOOTSTRAP_FILE --banner https://${QSS3BucketName}/${QSS3KeyPrefix}/scripts/banner_message.txt --enable true
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@

#$PIA = Get-ec2subnet -SubnetId $Global:pus1bId
#$IP = $PIA.CidrBlock.Substring(0,$PIA.CidrBlock.Length-4)

$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-489f8e2c'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:BastionSecurityGroupId
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus1bId
			PrivateIpAddress = "10.0.128.5"
			#AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:BastionServer = New-EC2Instance @parameters
($Global:BastionServer.Instances).InstanceID
Add-EC2Tag -key Name -value $Global:BastionServerTag -resourceId ($Global:BastionServer.Instances).InstanceID
}

Function LOG {
LogWrite "Get-Date"

LogWrite "External IP: $Global:LocalPC_ExteralIP"

LogWrite "Region"
LogWrite $Global:Region.RegionName

LogWrite $Global:VPCTag
LogWrite "VPC ID : $Global:vpcId"

LogWrite $Global:igwTag
LogWrite "Internet Gateway ID : $Global:igwAId"

LogWrite $Global:rtTag
LogWrite "Route Table ID : $Global:rtPublicID"

LogWrite $Global:pus1Tag 
LogWrite "Public Subnet 1 ID : $Global:pus1bId"

LogWrite $Global:pvs1Tag 
LogWrite "Private Subnet1 ID : $Global:pvs1aId"

LogWrite $Global:ntgTag
LogWrite "NAT Gateway ID : $Global:ntgId"

LogWrite $Global:rtTag
LogWrite "Public Route Table ID : $Global:rtPublicID"

LogWrite $Global:rtpvtTag
LogWrite "Private Route Table ID : $Global:rtPrivateID"

LogWrite "$Global:BastionServerTag"
LogWrite ($Global:BastionServer.Instances).InstanceID

LogWrite "BastionHostPublicIp"
LogWrite "BastionHostPublicIp"

LogWrite "BastionHostPublicDNS"
LogWrite "BastionHostPublicDNS"
}

Function Build_Exercise {
Login_to_AWS
AWSRegion
Variables
createVPC
enableDNS
createGateway
createRouteTable
createPublicSubnet1B
createPublicSubnet2C
CreateNATGateway
Start-Sleep -Seconds 5
createPrivateRouteTable
createPrivateSubnet
createBastionSecurityGroup
createKeyPair
BastionServer
LOG
AWS_Menu
}

Function Delete_Exercise {
Remove-EC2Instance -InstanceID ($Global:PrivateDBServer.Instances).InstanceID -Force
Remove-EC2Instance -InstanceID ($Global:PublicServer.Instances).InstanceID -Force
Remove-EC2Instance -InstanceID ($Global:PublicServer2.Instances).InstanceID -Force
Start-Sleep -Seconds 20
Remove-EC2NatGateway -NatGatewayId $Global:ntgId -Force
Remove-ELBLoadBalancer -LoadBalancerName $Global:LBname -Force
Remove-EC2Subnet -SubnetId $Global:pvs1aId -Force
Remove-EC2Subnet -SubnetId $Global:pus1bId -Force
Remove-EC2Subnet -SubnetId $Global:pus2bId -Force
Remove-EC2SecurityGroup -GroupId $Global:BastionSecurityGroupId -Force
Remove-EC2SecurityGroup -GroupId $Global:securityGroup2Id -Force
Remove-EC2SecurityGroup -GroupId $Global:securityGroup3Id -Force
Remove-EC2InternetGateway -InternetGatewayId $Global:igwAId -Force
Start-Sleep -Seconds 20
Remove-EC2Address -AllocationId $Global:eipId -Force
Remove-EC2Vpc -vpcID $Global:vpcId -Force
Remove-EC2KeyPair $Global:KeyPairName -Force
$RemovePem = "$Global:Outpath" + "\" + "$Global:KeyPairName" + ".pem"
Remove-Item $RemovePem -Force
Remove-ASAutoScalingGroup $AutoScalingGroupName -Force
Remove-ASLaunchConfiguration $Global:LaunchConfigurationName  -Force

AWS_Menu
}

Function Variables {
$Tag = read-host "Name of Demo"

$LogDate = Get-Date -UFormat "%y%h%Y_%H%M"
$Global:Outpath  = "C:\Jedi\PowerShell\Exercise"
$Global:Logfile = "C:\Jedi\PowerShell\Exercise\$LogDate" + "$Tag" + "_Exercise.log"

$Global:KeyPairName = $Tag
$Global:VPCTag = $Tag + "-VPC"
$Global:igwTag = $Tag + "-IGW"
$Global:rtTag = $Tag + "-Public Route Table"
$Global:pus1Tag = $Tag + "-Public Subnet"
$Global:ntgTag = $Tag + "-NAT"
$Global:rtpvtTag = $Tag + "-Private Route Table"
$Global:pvs1Tag = $Tag + "-Private Subnet"
$Global:BastionSecurityGroupIdTag  = $Tag + "-SG"
$Global:BastionServerTag = $Tag + "-Private"

}

Function AWS_Menu {
# Menu TUI
Write-Host "`n AWS Menu:" -Fore Cyan
[int]$global:Menu = 0
while ( $global:Menu -lt 1 -or $global:Menu -gt 3 ){
Write-host "1. Create Kubernetes cluster" -Fore Cyan
Write-host "2. Delete Kubernetes cluster" -Fore Cyan
Write-host "3. Exit" -Fore Cyan
[Int]$global:Menu = read-host "Choose an option 1 to 3" }
Switch( $global:Menu ){
1{Build_Exercise}
2{Delete_Exercise}
3{Exit}
}
}
AWS_Menu
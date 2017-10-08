#Pre-defined Loging
Function LogWrite{
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

# Create new VPC
Function createVPC {
$vpcResult = New-EC2Vpc -Region $Global:Region.RegionName  -CidrBlock "172.10.0.0/16"
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
Write-Output "Internet Gateway ID : $Global:igwAId"
$igwResult = New-EC2InternetGateway
$Global:igwBId = $igwResult.InternetGatewayId
Write-Output "Internet Gateway ID : $Global:igwBId"
Add-EC2Tag -key Name -value $Global:igwTag -resourceId $Global:igwAId
Add-EC2InternetGateway -InternetGatewayId $Global:igwAId -VpcId $Global:vpcId
Add-EC2Tag -key Name -value $Global:igwTag -resourceId $Global:igwBId
Add-EC2InternetGateway -InternetGatewayId $Global:igwBId -VpcId $Global:vpcId
}

# Create new Route Table
Function createRouteTable {
$rtResultA = New-EC2RouteTable -Region $Global:Region.RegionName  -VpcId $Global:vpcId
$Global:rtAId = $rtResultA.RouteTableId
Add-EC2Tag -key Name -value $Global:rtTag -resourceId $Global:rtAId
Start-Sleep 4
$rtResultB = New-EC2RouteTable -Region $Global:Region.RegionName  -VpcId $Global:vpcId
$Global:rtBId = $rtResultB.RouteTableId
Add-EC2Tag -key Name -value $Global:rtTag -resourceId $Global:rtBId
Start-Sleep 4
}

# Create new Route
Function createRoute {
 $rResult = New-EC2Route -Region $Global:Region.RegionName  -RouteTableId $Global:rtAId -GatewayId $Global:igwAId -DestinationCidrBlock "0.0.0.0/0"
 $rResult = New-EC2Route -Region $Global:Region.RegionName  -RouteTableId $Global:rtBId -GatewayId $Global:igwBId -DestinationCidrBlock "0.0.0.0/0"
 }
 
# Public Subnets with IP's
Function createPublicSubnet1A {
$AZ = $Global:Region.RegionName + "a"
$pus1aResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.2.0/24" -AvailabilityZone "$AZ"
$Global:pus1aId = $pus1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pus1aId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus1aId
}

Function createPublicSubnet1B {
$AZ = $Global:Region.RegionName + "b"
$pus1bResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.3.0/24" -AvailabilityZone "$AZ"
$Global:pus1bId = $pus1bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pus1bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus1bId
}

Function createPublicSubnet2A {
$AZ = $Global:Region.RegionName + "a"
$pus2aResult = New-EC2Subnet -Region $Global:Region.RegionName  -VpcId $Global:vpcId -CidrBlock "172.10.6.0/24" -AvailabilityZone "$AZ"
$Global:pus2aId = $pus2aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pus2aId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus2aId
}

Function createPublicSubnet2B {
$AZ = $Global:Region.RegionName + "b"
$pus2bResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.7.0/24" -AvailabilityZone "$AZ"
$Global:pus2bId = $pus2bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pus2bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus2bId
}

Function createPublicSubnet3A {
$AZ = $Global:Region.RegionName + "a"
$pus3aResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.10.0/24" -AvailabilityZone "$AZ"
$Global:pus3aId = $pus3aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pus3aId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus3aId
}

Function createPublicSubnet3b {
$AZ = $Global:Region.RegionName + "b"
$pus3bResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.11.0/24" -AvailabilityZone "$AZ"
$Global:pus3bId = $pus3bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pus3bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus3bId
}

# Private Subnets with IP's
Function createPrivateSubnet1A {
$AZ = $Global:Region.RegionName + "a"
$pvs1aResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.51.0/24" -AvailabilityZone "$AZ"
$Global:pvs1aId = $pvs1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pvs1aId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pvs1aId
}

Function createPrivateSubnet1B {
$AZ = $Global:Region.RegionName + "b"
$pvs1bResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.52.0/24" -AvailabilityZone "$AZ"
$Global:pvs1bId = $pvs1bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pvs1bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pvs1bId
}

Function createPrivateSubnet2A {
$AZ = $Global:Region.RegionName + "a"
$pvs2aResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.55.0/24" -AvailabilityZone "$AZ"
$Global:pvs2aId = $pvs2aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pvs2aId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pvs2aId
}

Function createPrivateSubnet2B {
$AZ = $Global:Region.RegionName + "b"
$pvs2bResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.56.0/24" -AvailabilityZone "$AZ"
$Global:pvs2bId = $pvs2bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pvs2bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pvs2bId
}

Function createPrivateSubnet3A {
$AZ = $Global:Region.RegionName + "a"
$pvs3aResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.60.0/24" -AvailabilityZone "$AZ"
$Global:pvs3aId = $pvs3aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pvs3aId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pvs3aId
}

Function createPrivateSubnet3B {
$AZ = $Global:Region.RegionName + "b"
$pvs3bResult = New-EC2Subnet -Region $Global:Region.RegionName -VpcId $Global:vpcId -CidrBlock "172.10.61.0/24" -AvailabilityZone "$AZ"
$Global:pvs3bId = $pvs3bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pvs3bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pvs3bId
}

#Create HTTP Listeners
Function createHTTPlistener {
# Create HTTP Listener
$Global:HTTPListener = New-Object -TypeName "Amazon.ElasticLoadBalancing.Model.Listener"
$Global:HTTPListener.Protocol = "http"
$Global:HTTPListener.InstancePort = 80
$Global:HTTPListener.LoadBalancerPort = 80

$Global:HTTPListener2 = New-Object -TypeName "Amazon.ElasticLoadBalancing.Model.Listener"
$Global:HTTPListener2.Protocol = "http"
$Global:HTTPListener2.InstancePort = 8080
$Global:HTTPListener2.LoadBalancerPort = 8080
}

#Create HTTPS Listeners
Function createHTTPSlistener {
$Global:HTTPSListener = New-Object -TypeName "Amazon.ElasticLoadBalancing.Model.Listener"
$Global:HTTPSListener.Protocol = "http"
$Global:HTTPSListener.InstancePort = 443
$Global:HTTPSListener.LoadBalancerPort = 80
$Global:HTTPSListener.SSLCertificateId = "YourSSL"
}

# Create KeyPair
Function createKeyPair {
#create a KeyPair, this is used to encrypt the Administrator password.
$keypair = New-EC2KeyPair -KeyName $Global:Rancher_Key_Lab
"$($keypair.KeyMaterial)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:Rancher_Key_Lab.pem"
"KeyName: $($keypair.KeyName)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:Rancher_Key_Lab.pem" -Append
"KeyFingerprint: $($keypair.KeyFingerprint)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:Rancher_Key_Lab.pem" -Append
}

Function createEC2Security {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:createSG;
    GroupDescription = "Security Group for Rancher Instance"
}
$Global:securityGroupId = New-EC2SecurityGroup @securityGroupParameters;
$IP = $Global:LocalPC_ExteralIP + "/32"
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges="$IP" }
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges=$IP}
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges=$IP}
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges=$IP}
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges=$IP}
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges=$IP}
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges=$IP}

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroupId -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroupId | Get-EC2SecurityGroup).IpPermissions
Add-EC2Tag -key Name -value $Global:securityGroupIdTag -resourceId $Global:securityGroupId

}

# Create EC2 Instance
Function createRancherManagerServer {
$userdata = @"
#!/bin/bash
wget -qO- https://get.docker.com/ | sh
docker run -d --restart=always -p 8080:8080 rancher/server
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@
 
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            ImageId = $Global:ImageID
			#ImageId = 'ami-94c479fb'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:Rancher_Key_Lab
            SecurityGroupId = $Global:securityGroupId
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus1aId
			AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:RancherManagerServer = New-EC2Instance @parameters
($Global:RancherManagerServer.Instances).InstanceID
Add-EC2Tag -key Name -value $Global:RancherManagerServerTag -resourceId ($Global:RancherManagerServer.Instances).InstanceID

}

# Create Load Balancer
Function createLB {
New-ELBLoadBalancer -LoadBalancerName $Global:LBname -Listeners @($Global:HTTPListener, $Global:HTTPListener2) -SecurityGroups @($Global:securityGroupId) -Subnets @($Global:pus1aId, $Global:pus2aId) -Scheme 'internet-facing'Add-EC2Tag -key Name -value $Global:LBTag -resourceId $Global:pvs1aId
}

# Attach LB to ELB
Function attachLB_ELB {
Register-ELBInstanceWithLoadBalancer -LoadBalancerName $Global:LBname -Instances @(($Global:RancherManagerServer.Instances).InstanceID)
}

# Create and Set Application Cookie Stickiness Policy
Function AppCookie {
New-ELBAppCookieStickinessPolicy -LoadBalancerName $Global:Rancher_Key_Lab -PolicyName "SessionName" -CookieName "CookieName"
Set-ELBLoadBalancerPolicyOfListener -LoadBalancerName $Global:Rancher_Key_Lab -LoadBalancerPort 80 -PolicyNames "SessionName"
}

#
Function AutoScalingGroup {
$Global:LaunchConfigurationName = $Global:AutoScalingTag
New-ASLaunchConfiguration -LaunchConfigurationName $Global:LaunchConfigurationName -InstanceType "t2.micro" -ImageId "ami-489f8e2c" -SecurityGroup "$Global:securityGroup2Id"

$Global:AutoScalingGroupName = $Global:AutoScalingTag
New-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName -LaunchConfigurationName $Global:LaunchConfigurationName -MinSize 2 -MaxSize 6 -AvailabilityZone @($Global:PS1AZ, $Global:PS2AZ)
$AutoScalingResult = Get-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName
}

# CloudWatch to spin up 2 instances incase of demand
Function CloudWatch {
#Create dimension to measure CPU across the entire auto scaling group
$Dimension = New-Object 'Amazon.CloudWatch.Model.Dimension'
$Dimension.Name = 'AutoScalingGroupName'
$Dimension.Value = $Global:AutoScalingGroupName

#Create a policy to add two instances
$ScaleOutArn = Write-ASScalingPolicy -PolicyName 'AddTwoInstances' -AutoScalingGroupName $Global:AutoScalingGroupName -ScalingAdjustment 2 -AdjustmentType 'ChangeInCapacity' -Cooldown (30*60)
Write-CWMetricAlarm -AlarmName 'AS75' -AlarmDescription 'Add capacity when average CPU within the auto scaling group is more than 75%' -MetricName 'CPUUtilization' -Namespace 'AWS/EC2' -Statistic 'Average' -Period (60*5) -Threshold 75 -ComparisonOperator 'GreaterThanThreshold' -EvaluationPeriods 2 -AlarmActions $ScaleOutArn -Unit 'Percent' -Dimensions $Dimension

#Create a policy to remove two instances
$ScaleInArn = Write-ASScalingPolicy -PolicyName 'RemoveTwoInstances' -AutoScalingGroupName $Global:AutoScalingGroupName -ScalingAdjustment -2 -AdjustmentType 'ChangeInCapacity' -Cooldown (30*60)
Write-CWMetricAlarm -AlarmName 'AS25' -AlarmDescription 'Remove capacity when average CPU within the auto scaling group is less than 25%' -MetricName 'CPUUtilization' -Namespace 'AWS/EC2' -Statistic 'Average' -Period (60*5) -Threshold 25 -ComparisonOperator 'LessThanThreshold' -EvaluationPeriods 2 -AlarmActions $ScaleInArn -Unit 'Percent' -Dimensions $Dimension
}

# Variables for the Exercise
Function Variables {

$Global:ImageID = ((Get-EC2Image -Region $Global:Region.RegionName -Filter @{"Name"="name";"Value"="*ubuntu*"} | sort -Property CreationDate -Descending)[0]).imageid

$Tag = read-host "Name of Demo"

$LogDate = Get-Date -UFormat "%y%h%Y_%H%M"
$Global:Outpath  = "C:\Jedi\Keys"
$Global:Logfile = "C:\Jedi\PowerShell\Exercise\$LogDate" + "$Tag" + "_Exercise.log"

$Global:Rancher_Key_Lab = $Tag
$Global:VPCTag = $Tag + "-VPC"
$Global:igwTag = $Tag + "-IGW"
$Global:rtTag = $Tag + "-Main Route Table"
$Global:pus1Tag = $Tag + "-Public Subnet	1"
$Global:pus2Tag = $Tag + "-Public Subnet	2"
$Global:ntgTag = $Tag + "-NAT"
$Global:rtpvtTag = $Tag + "-Private Route Table"
$Global:pvs1Tag = $Tag + "-Private Subnet 2"
$Global:securityGroupIdTag  = $Tag + "-Rancher-SG"

$Global:LBTag = $Tag + "-ELB"
$Global:LBname = $Global:LBTag
$Global:PrivateServerTag = $Tag + "-Private 1"
$Global:PublicServerTag = $Tag + "-Public 1"
$Global:PublicServerTag2 = $Tag + "-Public 2"
$Global:AutoScalingTag = $Tag + "-WebServer-AG"
}

# Build Rancher Exercise
Function Build_Exercise {
Login_to_AWS
createVPC
enableDNS
createGateway
combineVPC_Gateway
createRouteTable
createRoute
createPublicSubnet1A
createPublicSubnet1B
createPublicSubnet2A
createPublicSubnet2B
createPublicSubnet3A
createPublicSubnet3B
createPrivateSubnet1A
createPrivateSubnet1B
createPrivateSubnet2A
createPrivateSubnet2B
createPrivateSubnet3A
createPrivateSubnet3B
createKeyPair
createEC2Security
createServer
createHTTPlistener
createHTTPSlistener
createLB
attachLB_ELB

}

# Clean up if this is for a LAB or demo
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
Remove-EC2SecurityGroup -GroupId $Global:securityGroup1Id -Force
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

# Basic TUI 
Function AWS_Menu {
# Menu TUI
Write-Host "`n AWS Menu:" -Fore Cyan
[int]$global:Menu = 0
while ( $global:Menu -lt 1 -or $global:Menu -gt 3 ){
Write-host "1. Create Rancher Exercise" -Fore Cyan
Write-host "2. Delete Rancher Exercise" -Fore Cyan
Write-host "3. Exit" -Fore Cyan
[Int]$global:Menu = read-host "Choose an option 1 to 3" }
Switch( $global:Menu ){
1{Build_Exercise}
2{Delete_Exercise}
3{Exit}
}
}
AWS_Menu
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
#If (!(Import-Module SSMDevOps)){ Import-Module SSMDevOps }

#Set-AWSCredential -AccessKey ###### -SecretKey ###### -StoreAs ECS_Zach
Initialize-AWSDefaults -ProfileName ECS_Zach
Get-AWSCredential -ListProfileDetail

#Collect Exteral IP
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

# Create new Internet Gateway
Function createGateway{
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
}

# Public Subnets
Function createPublicSubnet1B{
$Global:PS1AZ = $Global:Region.RegionName + "a"
$pus1BResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "192.168.1.0/24" -AvailabilityZone "$Global:PS1AZ"
$Global:pus1bId = $pus1BResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPublicID -SubnetId $Global:pus1bId
Add-EC2Tag -key Name -value $Global:pus1Tag -resourceId $Global:pus1bId

}
Function createPublicSubnet2C{
$Global:PS2AZ = $Global:Region.RegionName + "b"
$pus2bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "192.168.3.0/24" -AvailabilityZone "$Global:PS2AZ"
$Global:pus2bId = $pus2bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPublicID -SubnetId $Global:pus2bId
Add-EC2Tag -key Name -value $Global:pus2Tag -resourceId $Global:pus2bId
}

#Create EIP Address
Function CreateEIP{
$eipResult = New-EC2Address -Domain $Global:vpcId
$Global:eipId = $eipResult.AllocationId
$Global:eIP = $eipResult.PublicIp
}

#Create NAT Gateway
Function CreateNATGateway{
$ntgResult = New-EC2NatGateway -SubnetId $Global:pus1bId -AllocationId $Global:eipId
$ntgId = Get-EC2NatGateway | Where-Object {$_.VpcId -eq $Global:vpcId}
$Global:ntgId = $ntgId.NatGatewayId
Add-EC2Tag -key Name -value $Global:ntgTag -resourceId $Global:ntgId
}
 
 #Create Private Route Table
Function createPrivateRouteTable{ 
$rtResultPvt = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtPrivateID = $rtResultPvt.RouteTableId
Add-EC2Tag -key Name -value $Global:rtpvtTag -resourceId $Global:rtPrivateID
$rpvtResult = New-EC2Route -RouteTableId $Global:rtPrivateID -NatGatewayId $Global:ntgId -DestinationCidrBlock '0.0.0.0/0'
 }
 
# Private Subnets
Function createPrivateSubnet{
$Global:PVS1AZ = $Global:Region.RegionName + "a"
$pvs1aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "192.168.2.0/24" -AvailabilityZone "$Global:PVS1AZ"
$Global:pvs1aId = $pvs1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPrivateID -SubnetId $Global:pvs1aId
Add-EC2Tag -key Name -value $Global:pvs1Tag -resourceId $Global:pvs1aId
 }

Function createEC2Security1 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:securityGroup1IdTag;
    GroupDescription = "Load balancer security group"
}
$IP = "0.0.0.0/0"
$Global:securityGroup1Id = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges=$IP}
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges=$IP}
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges=$IP}
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges=$IP}
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges=$IP}
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges=$IP}

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroup1Id -IpPermission @( $ip6, $ip7, $ip8)
($Global:securityGroup1Id | Get-EC2SecurityGroup).IpPermissions  
Add-EC2Tag -key Name -value $Global:securityGroup1IdTag -resourceId $Global:securityGroup1Id
}

Function createEC2Security2 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:securityGroup2IdTag;
    GroupDescription = "Web server security group"
}
$IP = $Global:LocalPC_ExteralIP + "/32"
$Global:securityGroup2Id = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges=$IP}
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges=$IP}
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges=$IP}
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges=$IP}
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges=$IP}
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges=$IP}

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroup2Id -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroup2Id | Get-EC2SecurityGroup).IpPermissions  
Add-EC2Tag -key Name -value $Global:securityGroup2IdTag -resourceId $Global:securityGroup2Id
}

Function createEC2Security3 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:securityGroup3IdTag;
    GroupDescription = "Database security group"
}
$IP = $Global:LocalPC_ExteralIP + "/32"
$Global:securityGroup3Id = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges=$IP}
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges=$IP}
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges=$IP}
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges=$IP}
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges=$IP}
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges=$IP}

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroup3Id -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroup3Id | Get-EC2SecurityGroup).IpPermissions  
Add-EC2Tag -key Name -value $Global:securityGroup3IdTag -resourceId $Global:securityGroup3Id
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
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@

$PIA = Get-ec2subnet -SubnetId $Global:pvs1aId
$IP = $PIA.CidrBlock.Substring(0,$PIA.CidrBlock.Length-4)

$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-489f8e2c'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup3Id
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

Function BastionServer {
$userdata = @"
#!/bin/bash
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@

$PIA = Get-ec2subnet -SubnetId $Global:pvs1aId
$IP = $PIA.CidrBlock.Substring(0,$PIA.CidrBlock.Length-4)

$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-489f8e2c'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup3Id
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pvs1aId
			PrivateIpAddress = $IP  + "250"
			#AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:BastionServer = New-EC2Instance @parameters
($Global:BastionServer.Instances).InstanceID
Add-EC2Tag -key Name -value $Global:BastionServerTag -resourceId ($Global:BastionServer.Instances).InstanceID
}

 #Create HTTP Listeners
Function createHTTPlistener {
$Global:HTTPListener = New-Object -TypeName 'Amazon.ElasticLoadBalancing.Model.Listener'
$Global:HTTPListener.Protocol = 'http'
$Global:HTTPListener.InstancePort = 80
$Global:HTTPListener.LoadBalancerPort = 80

$Global:HTTPListener2 = New-Object -TypeName 'Amazon.ElasticLoadBalancing.Model.Listener'
$Global:HTTPListener2.Protocol = 'http'
$Global:HTTPListener2.InstancePort = 8080
$Global:HTTPListener2.LoadBalancerPort = 8080
}

#Create HTTPS Listeners
Function createHTTPSlistener {
$Global:HTTPSListener = New-Object -TypeName 'Amazon.ElasticLoadBalancing.Model.Listener'
$Global:HTTPSListener.Protocol = 'http'
$Global:HTTPSListener.InstancePort = 443
$Global:HTTPSListener.LoadBalancerPort = 80
$Global:HTTPSListener.SSLCertificateId = 'YourSSL'
}

 # Create Load Balancer
Function createLB {
New-ELBLoadBalancer -LoadBalancerName $Global:LBname -Listeners @($Global:HTTPListener, $Global:HTTPListener2) -SecurityGroups @($Global:securityGroup1Id) -Subnets @($Global:pus1bId, $Global:pus2bId) -Scheme 'internet-facing'
Add-EC2Tag -key Name -value $Global:LBTag -resourceId $Global:pvs1aId
}


Function PublicWebServer {
$userdata = @"
#!/bin/bash
yum update -y
yum install -y php
yum install -y php-mysql
yum install -y mysql
yum install -y httpd
echo "<html><body><h1>Public Server 1</h1></body></html>" > /var/www/html/index.html
service httpd start
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@
 
$PIA = Get-ec2subnet -SubnetId $Global:pus1bId
$IP = $PIA.CidrBlock.Substring(0,$PIA.CidrBlock.Length-4)

$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-489f8e2c'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup2Id
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus1bId
			PrivateIpAddress = $IP + "10"
			AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:PublicServer = New-EC2Instance @parameters
($Global:PublicServer.Instances).InstanceID
Add-EC2Tag -key Name -value $Global:PublicServerTag -resourceId ($Global:PublicServer.Instances).InstanceID
}

Function PublicWebServer2 {
$userdata = @"
#!/bin/bash
yum update -y
yum install -y php
yum install -y php-mysql
yum install -y mysql
yum install -y httpd
echo "<html><body><h1>Public Server 2</h1></body></html>" > /var/www/html/index.html
service httpd start
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@
 
$PIA = Get-ec2subnet -SubnetId $Global:pus2bId
$IP = $PIA.CidrBlock.Substring(0,$PIA.CidrBlock.Length-4)

$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-489f8e2c'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup2Id
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus2bId
			PrivateIpAddress = $IP + "50"
			AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:PublicServer2 = New-EC2Instance @parameters
($Global:PublicServer2.Instances).InstanceID
Add-EC2Tag -key Name -value $Global:PublicServerTag2 -resourceId ($Global:PublicServer2.Instances).InstanceID
}

Function AutoScalingGroup {
$Global:LaunchConfigurationName = $Global:AutoScalingTag
New-ASLaunchConfiguration -LaunchConfigurationName $Global:LaunchConfigurationName -InstanceType "t2.micro" -ImageId "ami-489f8e2c" -SecurityGroup "$Global:securityGroup2Id"

$Global:AutoScalingGroupName = $Global:AutoScalingTag
New-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName -LaunchConfigurationName $Global:LaunchConfigurationName -MinSize 2 -MaxSize 6 -AvailabilityZone @($Global:PS1AZ, $Global:PS2AZ)
$AutoScalingResult = Get-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName
}

# Attach LB to ELB
Function attachLB_ELB {
Register-ELBInstanceWithLoadBalancer -LoadBalancerName $Global:LBname -Instances @(($Global:PublicServer.Instances).InstanceID, ($Global:PublicServer2.Instances).InstanceID)
}

# Create and Set Application Cookie Stickiness Policy
Function AppCookie {
New-ELBAppCookieStickinessPolicy -LoadBalancerName $Global:LBname -PolicyName ‘SessionName’ -CookieName ‘CookieName’
Set-ELBLoadBalancerPolicyOfListener -LoadBalancerName $Global:LBname -LoadBalancerPort 80 -PolicyNames ‘SessionName’
}

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

LogWrite $Global:pus2Tag
LogWrite "Public Subnet 2 ID : $Global:pus2bId"

LogWrite $Global:pvs1Tag 
LogWrite "Private Subnet1 ID : $Global:pvs1aId"

LogWrite Elastic IP
LogWrite "EIP Address: $Global:eIP"

LogWrite $Global:ntgTag
LogWrite "NAT Gateway ID : $Global:ntgId"

LogWrite $Global:rtTag
LogWrite "Public Route Table ID : $Global:rtPublicID"

LogWrite $Global:rtpvtTag
LogWrite "Private Route Table ID : $Global:rtPrivateID"

LogWrite $Global:AutoScalingTag
LogWrite "$AutoScalingResult"


LogWrite "$Global:PrivateServerTag"
LogWrite ($Global:PrivateDBServer.Instances).InstanceID

LogWrite "$Global:PublicServerTag"
LogWrite ($Global:PublicServer.Instances).InstanceID

LogWrite $Global:PublicServerTag2
LogWrite ($Global:PublicServer2.Instances).InstanceID

LogWrite $Global:LBname 
LogWrite $Global:ELB_DNS

LogWrite
LogWrite
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
CreateEIP
CreateNATGateway
Start-Sleep -Seconds 5
createPrivateRouteTable
createPrivateSubnet
createEC2Security1
createEC2Security2
createEC2Security3
createKeyPair
PrivateDBServer
createHTTPlistener
createHTTPSlistener
createLB
PublicWebServer
PublicWebServer2
AutoScalingGroup
attachLB_ELB
CloudWatch
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

Function Variables {
$Tag = read-host "Name of Demo"

$LogDate = Get-Date -UFormat "%y%h%Y_%H%M"
$Global:Outpath  = "C:\Jedi\PowerShell\Exercise"
$Global:Logfile = "C:\Jedi\PowerShell\Exercise\$LogDate" + "$Tag" + "_Exercise.log"

$Global:KeyPairName = $Tag
$Global:VPCTag = $Tag + "-VPC"
$Global:igwTag = $Tag + "-IGW"
$Global:rtTag = $Tag + "-Main Route Table"
$Global:pus1Tag = $Tag + "-Public Subnet	1"
$Global:pus2Tag = $Tag + "-Public Subnet	2"
$Global:ntgTag = $Tag + "-NAT"
$Global:rtpvtTag = $Tag + "-Private Route Table"
$Global:pvs1Tag = $Tag + "-Private Subnet 2"
$Global:securityGroup1IdTag  = $Tag + "-ELB-SG"
$Global:securityGroup2IdTag  = $Tag + "-WebServer-SG"
$Global:securityGroup3IdTag  = $Tag + "-DB-SG"
$Global:LBTag = $Tag + "-ELB"
$Global:LBname = $Global:LBTag
$Global:PrivateServerTag = $Tag + "-Private 1"
$Global:PublicServerTag = $Tag + "-Public 1"
$Global:PublicServerTag2 = $Tag + "-Public 2"
$Global:AutoScalingTag = $Tag + "-WebServer-AG"
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
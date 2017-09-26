# Login to AWS Subscription
Function Login_to_AWS {
If ( (Get-ExecutionPolicy) -ne "RemoteSigned")
{
set-ExecutionPolicy RemoteSigned -Scope Process -Force
}

#Set-AWSCredential -AccessKey ###### -SecretKey ###### -StoreAs ECS_Zach
Initialize-AWSDefaults

If (!(Import-Module AWSPowerShell)){ Import-Module AWSPowerShell }
#If (!(Import-Module SSMDevOps)){ Import-Module SSMDevOps }

Get-AWSCredential -ListProfileDetail
$Global:LocalPC_ExteralIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
AWSRegion
Menu
}
# Create new VPC
Function createVPC{
$vpcResult = New-EC2Vpc -CidrBlock "$Global:SubnetRange"
$Global:vpcId = $vpcResult.VpcId
Write-Output "VPC ID : $Global:vpcId"
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
Write-Output "Internet Gateway ID : $Global:igwAId"
}

# Attach Internet Gateway to VPC
Function combineVPC_Gateway{
Add-EC2InternetGateway -InternetGatewayId $Global:igwAId -VpcId $Global:vpcId
}

# Create new Route Table
Function createRouteTable {
$rtResultA = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtPublicID = $rtResultA.RouteTableId
Write-Output "Route Table ID : $Global:rtPublicID"
$rtResultB = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtPrivateID = $rtResultB.RouteTableId
Write-Output "Route Table ID : $Global:rtPrivateID"
}

# Create new Route
Function createRoute {
 $rResult = New-EC2Route -RouteTableId $Global:rtPublicID -GatewayId $Global:igwAId -DestinationCidrBlock '0.0.0.0/0'
 $rResult = New-EC2Route -RouteTableId $Global:rtPrivateID -GatewayId $Global:igwAId -DestinationCidrBlock '0.0.0.0/0'
 }
 
# Public IP's
Function createPublicSubnet1B{
$AZ = $Global:Region.RegionName + "b"
$pus1BResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock $Global:PublicSubnet -AvailabilityZone "$AZ"
$Global:pus1bId = $pus1BResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPublicID -SubnetId $Global:pus1bId
Write-Output "Subnet1 ID : $Global:pus1bId"
}
Function createPublicSubnet2C{
$AZ = $Global:Region.RegionName + "c"
$pus2bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock $Global:PublicSubnet2 -AvailabilityZone "$AZ"
$Global:pus2bId = $pus2bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPrivateID -SubnetId $Global:pus2bId
Write-Output "Subnet1 ID : $Global:pus2bId"
}

# Private IP's
Function createPrivateSubnet1A{
$AZ = $Global:Region.RegionName + "a"
$pvs1aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock $Global:PrivateSubnet -AvailabilityZone "$AZ"
$Global:pvs1aId = $pvs1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtPublicID -SubnetId $Global:pvs1aId
Write-Output "Subnet1 ID : $Global:pvs1aId"
}

#Create HTTP Listeners
Function createHTTPlistener {
# Create HTTP Listener
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

# Create KeyPair
Function createKeyPair {
#create a KeyPair, this is used to encrypt the Administrator password.
$keypair = New-EC2KeyPair -KeyName $Global:KeyPairName
"$($keypair.KeyMaterial)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem"
"KeyName: $($keypair.KeyName)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
"KeyFingerprint: $($keypair.KeyFingerprint)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
}

# Security Groups
Function createEC2Security1 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:createSG1;
    GroupDescription = "Security Group for DEMO Webserver 1"
}
$Global:securityGroup1Id = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges="$Global:LocalPC_ExteralIP/0" }

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroup1Id -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroup1Id | Get-EC2SecurityGroup).IpPermissions  
}
Function createEC2Security2 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:createSG2;
    GroupDescription = "Security Group for DEMO Webserver 2"
}
$Global:securityGroup2Id = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges="$Global:LocalPC_ExteralIP/0" }

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroup2Id -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroup2Id | Get-EC2SecurityGroup).IpPermissions  
}
Function createEC2Security3 {
$securityGroupParameters = @{
    VpcId = $Global:vpcId;
    GroupName =  $Global:createSG3;
    GroupDescription = "Security Group for SQL Server"
}
$Global:securityGroup3Id = New-EC2SecurityGroup @securityGroupParameters;
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="0.0.0.0/0" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges="$Global:LocalPC_ExteralIP/0" }
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges="$Global:LocalPC_ExteralIP/0" }

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroup3Id -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroup3Id | Get-EC2SecurityGroup).IpPermissions  
}

# Create EC2 Instance
Function PublicWebServer {
$userdata = @"
#!/bin/bash
yum install httpd -y
yum update -y 
service httpd start 
chkconfig httpd on 
echo "<html><h1>Hello ECS Demo AWS WebServer 1!</h1></hmtl>" >/var/www/html/index.html
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@
 
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-d7b9a2b1'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup1Id
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus1bId
			PrivateIpAddress = "10.0.2.50"
			AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:PublicWebServer = New-EC2Instance @parameters
($Global:PublicWebServer.Instances).InstanceID
}
Function PublicWebServer2 {
$userdata = @"
#!/bin/bash
yum install httpd -y
yum update -y 
service httpd start 
chkconfig httpd on
echo "<html><h1>Hello ECS Demo AWS WebServer 2!</h1></hmtl>" >/var/www/html/index.html
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@
 
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-d7b9a2b1'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup2Id
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus2bId
			PrivateIpAddress = "10.0.3.50"
			AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:PublicWebServer2 = New-EC2Instance @parameters
($Global:PublicWebServer2.Instances).InstanceID
}
Function PrivateDBServer {
$userdata = @"
#!/bin/bash
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update
sudo apt-get install -y powershell
"@
 
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))
$parameters = @{
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-d7b9a2b1'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:KeyPairName
            securityGroupId = $Global:securityGroup3Id
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pvs1aId
			PrivateIpAddress = "10.0.1.50"
			#AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$Global:PrivateDBServer = New-EC2Instance @parameters
($Global:PrivateDBServer.Instances).InstanceID
}
#$reservation = New-Object 'collections.generic.list[string]' $reservation.add("r-bdb88ab0") $filter_reservation = New-Object Amazon.EC2.Model.Filter -Property @{Name = "reservation-id"; Values = $reservation}
#(Get-EC2Instance -Filter $filter_reservation).Instances

# Create Load Balancer
Function createLB {
New-ELBLoadBalancer -LoadBalancerName $Global:LBname -Listeners @($Global:HTTPListener, $Global:HTTPListener2) -SecurityGroups @($Global:securityGroup1Id) -Subnets @($Global:pus1bId, $Global:pus2bId) -Scheme 'internet-facing'
}

# Attach LB to ELB
Function attachLB_ELB {
$Global:PublicWebServerInstances = ($Global:PublicWebServer.Instances).InstanceID
$Global:PublicWebServerInstances2 = ($Global:PublicWebServer2.Instances).InstanceID
Register-ELBInstanceWithLoadBalancer -LoadBalancerName $Global:LBname -Instances @("$Global:PublicWebServerInstances", "$Global:PublicWebServerInstances2")
}

# Create and Set Application Cookie Stickiness Policy
Function AppCookie {
New-ELBAppCookieStickinessPolicy -LoadBalancerName $Global:KeyPairName -PolicyName 'SessionName' -CookieName 'CookieName'
Set-ELBLoadBalancerPolicyOfListener -LoadBalancerName $Global:KeyPairName -LoadBalancerPort 80 -PolicyNames 'SessionName'
}
Function StartWebsite {
$ELBebsite = Get-ELBLoadBalancer -LoadBalancerName $Global:LBname
$ELBebsite = $ELBebsite.CanonicalHostedZoneName
Start https://$ELBebsite
AWS_Menu
}

# Connect to Remote PowerShell console
Function Remote_PS {
$a = Get-EC2InstanceStatus
$Global:instanceId = $a.InstanceId
$Global:password = Get-EC2PasswordData -InstanceId $Global:instanceId -PemFile "$Global:Outpath\$Global:ServerName.pem" -Decrypt
$securepassword = ConvertTo-SecureString $Global:password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)

#Wait until PSSession is available
while ($true)
{
    $s = New-PSSession $Global:publicDNS -Credential $credential 2>$null
    if ($s -ne $null)
    {
        break
    }

    "$(Get-Date) Waiting for remote PS connection"
    Sleep -Seconds 10
}

Invoke-Command -Session $s {(Invoke-WebRequest http://169.254.169.254/latest/user-data).RawContent}

Remove-PSSession $s
}

# Add Webserver Option
Function DSC_WebServer_MOF {
Configuration SomeConfiguration
{
$Global:instanceId
$source = 'https://s3.amazonaws.com/aws-windows-samples-us-east-1/PSModules/SSMDevOps.zip'
$commands = @(
  'Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force',
  'Import-Module SSMDevOps',
  'Install-SsmDoIIS',
  'Start-DscConfiguration -Path Install-SsmDoIIS -Wait'
)
$parameter = @{
  source = $source;
  commands = $commands;
}
$document = 'AWS-InstallPowerShellModule'
$cmd = Send-SSMCommand –InstanceId $Global:instanceId –DocumentName $document –Parameter $parameter
}
Write-Host WebServer MOF Installed
}

# Install Webserver option
Function MOF_Install {
$securepassword = ConvertTo-SecureString $Global:password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("Administrator", $securepassword)
$cimSession = New-CimSession -ComputerName $Global:publicDNSName -Credential $credential -Authentication Negotiate
 
Start-DscConfiguration -Verbose -Wait -Path $Global:Logpath -Force -CimSession $cimSession
}

# Error Handling (Check if instance is running or terminated)
Function WaitForState ($Global:instanceId, $desiredstate) {
    while ($true)
    {
    Sleep -Seconds 30
       $statuses = Get-EC2InstanceStatus $Global:instanceId
       $status = $statuses[0]
       $state = $status.InstanceState.Name
       #$desiredstate = "running"
        if ($state -eq $desiredstate)
        {
            break;
        }
        "$(Get-Date) Current State = $state, Waiting for Desired State=$desiredstate"
        Sleep -Seconds 5
    }
}

# Error handling (Ping Instance to see if its allowing RDP access)
Function Check_ServerStatus {

Sleep -Seconds 2
#Wait for the running state
WaitForState $Global:instanceId "Running"
$a = Get-EC2InstanceStatus
$Global:instanceId = $a.InstanceId
$b = Get-EC2Instance $Global:instanceId
$Global:publicDNS = $b.Instances[0].PublicDnsName
Sleep -Seconds 10
#Wait for ping to succeed
while ($true)
{

    ping $Global:publicDNS
    if ($LASTEXITCODE -eq 0)
    {
        break
    }
    "$(Get-Date) Waiting for ping to succeed"
    Sleep -Seconds 10
}
}

# Clean Up for Lab system
Function CleanUp {
Remove-EC2Instance $Global:PublicWebServerInstances -Force
Remove-EC2Instance $Global:PublicWebServerInstances2  -Force
Remove-EC2Instance ($Global:PrivateDBServer.Instances).InstanceID -Force
Remove-EC2KeyPair $Global:KeyPairName -Force
Remove-ELBLoadBalancer -LoadBalancerName $Global:LBname -Force
Start-Sleep -Seconds 30
Remove-EC2KeyPair $Global:KeyPairName -Force
Remove-EC2SecurityGroup -GroupId $Global:securityGroup1Id -Force
Remove-EC2SecurityGroup -GroupId $Global:securityGroup2Id -Force
Remove-EC2SecurityGroup -GroupId $Global:securityGroup3Id -Force
Start-Sleep -Seconds 30
Remove-EC2Vpc $Global:vpcId -Force
AWS_Menu
}

#Setup Networking Params
Function SetupNetworking {

$SubnetRange = "Subnet Range Ex: 10.0.0.0/16"
$PulicSubnet1 = "Public Subnet Ex: 10.0.1.0/24"
$PublicSubnet2 = "Public Subnet2 Ex: 10.0.2.0/24"
$PrivateSubnet = "Private Subnet Ex: 10.0.3.0/24"
$SNetworking = $host.ui.Prompt("Setup Network","Enter values for these settings:",
@($SubnetRange,$PulicSubnet1,$PublicSubnet2,$PrivateSubnet))
$SetupNetworking = New-Object -TypeName PSObject -Property $SNetworking

  $Global:SubnetRange = $SetupNetworking."$SubnetRange"
  $Global:PublicSubnet = $SetupNetworking."$PulicSubnet1"
  $Global:PublicSubnet2 = $SetupNetworking."$PublicSubnet2"
  $Global:PrivateSubnet = $SetupNetworking."$PrivateSubnet"
  Error_SetupNetworking
}

Function Error_SetupNetworking{
$message  = 'Networking Data Confirmation'
$question = 'Are you sure you want to proceed?'

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
  Write-Host 'Confirmed'
} else {
  Write-Host 'You can now fix the issue'
  SetupNetworking
}
}

#Create Networking structure
Function CreateNetworking
{
createVPC
createGateway
combineVPC_Gateway
createRouteTable
createRoute
createPublicSubnet1B
createPublicSubnet2C
createPrivateSubnet1A
}

# Setup EC2
Function SetupEC2{
#----------------------------------------------------------
#DYNAMIC VARIABLES
#----------------------------------------------------------
cls
$Title="AWS Automation System"
Write-Host "================ $Title ================" -Fore Magenta

$Global:KeyPairName = Read-Host "Please enter a Unique KeyName"
$Global:LBname = Read-Host "Enter LoadBalancer Name"
$Global:createSG1 = Read-Host "Enter the name of Public Security Group"
$Global:createSG2 = Read-Host "Enter the name of Public Security Group"
$Global:createSG3 = Read-Host "Enter the name of Private Security Group"
$Global:Outpath = "C:\Jedi\PowerShell\ECS_Demo"

# Grab a list of Instances from AWS
$Global:InstanceTypeArray = @{
General_Purpose = @(
"t2.nano",
"t2.micro",
"t2.small",
"t2.medium",
"t2.large",
"t2.xlarge",
"t2.2xlarge",
"m4.large",
"m4.xlarge",
"m4.2xlarge",
"m4.4xlarge",
"m4.10xlarge",
"m4.16xlarge",
"m3.medium",
"m3.large",
"m3.xlarge",
"m3.2xlarge")
Compute_Optimized = @(
"c4.large",
"c4.xlarge",
"c4.2xlarge",
"c4.4xlarge",
"c4.8xlarge",
"c3.large",
"c3.xlarge",
"c3.2xlarge",
"c3.4xlarge",
"c3.8xlarge")
Memory_Optimized= @(
"r3.large",
"r3.xlarge",
"r3.2xlarge",
"r3.4xlarge",
"r3.8xlarge",
"r4.large",
"r4.xlarge",
"r4.2xlarge",
"r4.4xlarge",
"r4.8xlarge",
"r4.16xlarge",
"x1.16xlarge",
"x1.32xlarge")
Storage_Optimiozed = @(
"d2.xlarge",
"d2.2xlarge",
"d2.4xlarge",
"d2.8xlarge",
"i2.xlarge",
"i2.2xlarge",
"i2.4xlarge",
"i2.8xlarge",
"i3.large",
"i3.xlarge",
"i3.2xlarge",
"i3.4xlarge",
"i3.8xlarge",
"i3.16xlarge") 
Accelerated_Computing = @(
"f1.2xlarge",
"f1.16xlarge",
"p2.xlarge",
"p2.8xlarge",
"p2.16xlarge",
"g2.2xlarge",
"g2.8xlarge",
"g3.4xlarge",
"g3.8xlarge",
"g3.16xlarge")
}

# Select an AWS Image
# Instance TUI
Write-Host "`n Choose OS Type:" -Fore Cyan
[int]$global:ImageIDMenu = 0
while ( $global:ImageIDMenu -lt 1 -or $global:ImageIDMenu -gt 6 ){
Write-host "1. Windows" -Fore Cyan
Write-host "2. Linux" -Fore Cyan
Write-host "3. Ubuntu" -Fore Cyan
Write-host "4. Other" -Fore Cyan
Write-host "5. All" -Fore Cyan
Write-host "6. Free Tier" -Fore Cyan
[Int]$global:ImageIDMenu = read-host "Choose an option 1 to 6" }
Switch( $global:ImageIDMenu ){
1{$Global:ImageID = Get-EC2ImageByName * -Region $Global:Region.RegionName | Where-Object {$_.Description -like "*Windows*"} | Select-Object -Property ImageId, Description, CreationDate |  Out-GridView -PassThru}
2{$Global:ImageID = Get-EC2ImageByName * -Region $Global:Region.RegionName | Where-Object {$_.Description -like "*Windows*"} | Select-Object -Property ImageId, Description, CreationDate |  Out-GridView -PassThru}
3{$Global:ImageID = Get-EC2ImageByName * -Region $Global:Region.RegionName | Where-Object {$_.Description -like "*Windows*"} | Select-Object -Property ImageId, Description, CreationDate |  Out-GridView -PassThru}
4{$Global:ImageID = Get-EC2ImageByName * -Region $Global:Region.RegionName | Where-Object {$_.Description -like "*Windows*"} | Select-Object -Property ImageId, Description, CreationDate |  Out-GridView -PassThru}
5{$Global:ImageID = Get-EC2ImageByName * -Region $Global:Region.RegionName | Where-Object {$_.Description -like "*Windows*"} | Select-Object -Property ImageId, Description, CreationDate |  Out-GridView -PassThru}
6{$Global:ImageID = Get-EC2Image -ImageId ami-f97e8f80}
}

# Instance TUI
Write-Host "`n Choose Instance Type:" -Fore Cyan
[int]$global:InstanceTypeMenu = 0
while ( $global:InstanceTypeMenu -lt 1 -or $global:InstanceTypeMenu -gt 6 ){
Write-host "1. General Purpose" -Fore Cyan
Write-host "2. Compute Optimized" -Fore Cyan
Write-host "3. Memory Optimized" -Fore Cyan
Write-host "4. Storage Optimized" -Fore Cyan
Write-host "5. Accelerated Computing" -Fore Cyan
Write-host "6. Free Tier" -Fore Cyan
[Int]$global:InstanceTypeMenu = read-host "Choose an option 1 to 6" }
Switch( $global:InstanceTypeMenu ){
1{$Global:InstanceType = $Global:InstanceTypeArray.General_Purpose | Out-GridView -PassThru}
2{$Global:InstanceType = $Global:InstanceTypeArray.Compute_Optimized | Out-GridView -PassThru}
3{$Global:InstanceType = $Global:InstanceTypeArray.Memory_Optimized | Out-GridView -PassThru}
4{$Global:InstanceType = $Global:InstanceTypeArray.Storage_Optimiozed | Out-GridView -PassThru}
5{$Global:InstanceType = $Global:InstanceTypeArray.Accelerated_Computing | Out-GridView -PassThru}
6{$Global:InstanceType = "t2.micro"}
}
SetupEC2
}

Function Error_SetupEC2{
$message  = 'EC2 Data Confirmation'
$question = 'Are you sure you want to proceed?'

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
  Write-Host 'Confirmed'
} else {
  Write-Host 'You can now fix the issue'
  SetupEC2
}
}


Function CreateEC2{
SetupNetworking
CreateNetworking
createKeyPair
createEC2Security1
createEC2Security2
createEC2Security3
PublicWebServer
PublicWebServer2
PrivateDBServer
}

#Pick AWS Region
Function AWSRegion{
# Select a AWS Region of choice
$Global:RegionArray = (Get-EC2Region)
$Global:Region = $Global:RegionArray | Select-Object RegionName | Out-GridView -PassThru
Set-DefaultAWSRegion -Region $Global:Region.RegionName
}

# Menu for Network
Function Network{
# Menu TUI
Write-Host "`n Networking System:" -Fore Cyan
[int]$global:Menu = 0
while ( $global:Menu -lt 1 -or $global:Menu -gt 4 ){
Write-host "1. Setup Networking" -Fore Cyan
Write-host "2. Create Networking" -Fore Cyan
Write-host "3. Elasstic Load Balancing" -Fore Cyan
Write-host "4. Main Menu" -Fore Cyan
[Int]$global:Menu = read-host "Choose an option 1 to 4" }
Switch( $global:Menu ){
1{SetupNetworking}
2{CreateNetworking}
3{createELB}
4{Menu}
}
}

# Menu for EC2
Function EC2{
# Menu TUI
Write-Host "`n EC2 System:" -Fore Cyan
[int]$global:Menu = 0
while ( $global:Menu -lt 1 -or $global:Menu -gt 4 ){
Write-host "1. Setup EC2" -Fore Cyan
Write-host "2. Create EC2" -Fore Cyan
Write-host "3. Build EC2" -Fore Cyan
Write-host "4. Main Menu" -Fore Cyan
[Int]$global:Menu = read-host "Choose an option 1 to 4" }
Switch( $global:Menu ){
1{SetupEC2}
2{CreateEC2}
3{Build_Me2}
4{Menu}
}
}

# Main Menu
Function Menu{
# Menu TUI
Write-Host "`n Menu System:" -Fore Cyan
[int]$global:Menu = 0
while ( $global:Menu -lt 1 -or $global:Menu -gt 5 ){
Write-host "1. Login to AWS" -Fore Cyan
Write-host "2. Networking" -Fore Cyan
Write-host "3. EC2 - Servers" -Fore Cyan
Write-host "4. Clean Up Script for lab" -Fore Cyan
Write-host "4. Exit" -Fore Cyan
[Int]$global:Menu = read-host "Choose an option 1 to 5" }
Switch( $global:Menu ){
1{Login_to_AWS}
2{Network}
3{EC2}
4{CleanUp}
4{Exit}
}
}
Menu
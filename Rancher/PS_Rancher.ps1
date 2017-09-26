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
}

# Create new VPC
Function createVPC{
$vpcResult = New-EC2Vpc -CidrBlock "172.10.0.0/16"
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
$igwResult = New-EC2InternetGateway
$Global:igwBId = $igwResult.InternetGatewayId
Write-Output "Internet Gateway ID : $Global:igwBId"
}

# Attach Internet Gateway to VPC
Function combineVPC_Gateway{
Add-EC2InternetGateway -InternetGatewayId $Global:igwAId -VpcId $Global:vpcId
}

# Create new Route Table
Function createRouteTable {
$rtResultA = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtAId = $rtResultA.RouteTableId
Write-Output "Route Table ID : $Global:rtAId"
$rtResultB = New-EC2RouteTable -VpcId $Global:vpcId
$Global:rtBId = $rtResultB.RouteTableId
Write-Output "Route Table ID : $Global:rtBId"
}

# Create new Route
Function createRoute {
 $rResult = New-EC2Route -RouteTableId $Global:rtAId -GatewayId $Global:igwAId -DestinationCidrBlock ‘0.0.0.0/0’
 $rResult = New-EC2Route -RouteTableId $Global:rtBId -GatewayId $Global:igwAId -DestinationCidrBlock ‘0.0.0.0/0’
 }
 
# Public IP's
Function createPublicSubnet1A{
$AZ = $Global:Region.RegionName + "a"
$pus1aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.2.0/24" -AvailabilityZone "$AZ"
$Global:pus1bId = $pus1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pus1bId
Write-Output "Subnet1 ID : $Global:pus1bId"
}

# Public IP's
Function createPublicSubnet1B{
$AZ = $Global:Region.RegionName + "b"
$pus1bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.3.0/24" -AvailabilityZone "$AZ"
$Global:pus1bId = $pus1bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pus1bId
Write-Output "Subnet1 ID : $Global:pus1bId"
}

Function createPublicSubnet2A{
$AZ = $Global:Region.RegionName + "a"
$pus2aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.6.0/24" -AvailabilityZone "$AZ"
$Global:pus2aId = $pus2aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pus2aId
Write-Output "Subnet1 ID : $Global:pus2aId"
}

Function createPublicSubnet2B{
$AZ = $Global:Region.RegionName + "b"
$pus2bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.7.0/24" -AvailabilityZone "$AZ"
$Global:pus2Id = $pus2bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pus2bId
Write-Output "Subnet1 ID : $Global:pus2bId"
}

Function createPublicSubnet3A{
$AZ = $Global:Region.RegionName + "a"
$pus3aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.10.0/24" -AvailabilityZone "$AZ"
$Global:pus3aId = $pus3aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pus3aId
Write-Output "Subnet1 ID : $Global:pus3aId"
}

Function createPublicSubnet3b{
$AZ = $Global:Region.RegionName + "b"
$pus3bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.11.0/24" -AvailabilityZone "$AZ"
$Global:pus3bId = $pus3bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pus3bId
Write-Output "Subnet1 ID : $Global:pus3bId"
}

# Private IP's
Function createPrivateSubnet1A{
$AZ = $Global:Region.RegionName + "a"
$pvs1aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.51.0/24" -AvailabilityZone "$AZ"
$Global:pvs1aId = $pvs1aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pvs1aId
Write-Output "Subnet1 ID : $Global:pvs1aId"
}

Function createPrivateSubnet1B{
$AZ = $Global:Region.RegionName + "b"
$pvs1bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.52.0/24" -AvailabilityZone "$AZ"
$Global:pvs1bId = $pvs1bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pvs1bId
Write-Output "Subnet1 ID : $Global:pvs1bId"
}

Function createPrivateSubnet2A{
$AZ = $Global:Region.RegionName + "a"
$pvs2aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.55.0/24" -AvailabilityZone "$AZ"
$Global:pvs2aId = $pvs2aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pvs2aId
Write-Output "Subnet1 ID : $Global:pvs2aId"
}

Function createPrivateSubnet2B{
$AZ = $Global:Region.RegionName + "b"
$pvs2bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.56.0/24" -AvailabilityZone "$AZ"
$Global:pvs2bId = $pvs2bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pvs2bId
Write-Output "Subnet1 ID : $Global:pvs2bId"
}

Function createPrivateSubnet3A{
$AZ = $Global:Region.RegionName + "a"
$pvs3aResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.60.0/24" -AvailabilityZone "$AZ"
$Global:pvs3aId = $pvs3aResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtAId -SubnetId $Global:pvs3aId
Write-Output "Subnet1 ID : $Global:pvs3aId"
}

Function createPrivateSubnet3B {
$AZ = $Global:Region.RegionName + "b"
$pvs3bResult = New-EC2Subnet -VpcId $Global:vpcId -CidrBlock "172.10.61.0/24" -AvailabilityZone "$AZ"
$Global:pvs3bId = $pvs3bResult.SubnetId
Register-EC2RouteTable -RouteTableId $Global:rtBId -SubnetId $Global:pvs3bId
Write-Output "Subnet1 ID : $Global:pvs3bId"
}

#Create HTTP Listeners
Function createHTTPlistener {
# Create HTTP Listener
$Global:HTTPListener = New-Object -TypeName ‘Amazon.ElasticLoadBalancing.Model.Listener’
$Global:HTTPListener.Protocol = ‘http’
$Global:HTTPListener.InstancePort = 80
$Global:HTTPListener.LoadBalancerPort = 80

$Global:HTTPListener2 = New-Object -TypeName ‘Amazon.ElasticLoadBalancing.Model.Listener’
$Global:HTTPListener2.Protocol = ‘http’
$Global:HTTPListener2.InstancePort = 8080
$Global:HTTPListener2.LoadBalancerPort = 8080
}


#Create HTTPS Listeners
Function createHTTPSlistener {
$Global:HTTPSListener = New-Object -TypeName ‘Amazon.ElasticLoadBalancing.Model.Listener’
$Global:HTTPSListener.Protocol = ‘http’
$Global:HTTPSListener.InstancePort = 443
$Global:HTTPSListener.LoadBalancerPort = 80
$Global:HTTPSListener.SSLCertificateId = ‘YourSSL’
}

# Create Load Balancer
Function createLB {
New-ELBLoadBalancer -LoadBalancerName $Global:Rancher_Key_Lab -Listeners @($Global:HTTPListener, $Global:HTTPListener2) -SecurityGroups @($Global:securityGroupId) -Subnets @($Global:pus1Iad, $Global:sn2Id) -Scheme ‘internet-facing’
}

# Attach LB to ELB
Function attachLB_ELB {
Register-ELBInstanceWithLoadBalancer -LoadBalancerName $Global:Rancher_Key_Lab -Instances @(‘instance1ID’, ‘instance2ID’)
}

# Create and Set Application Cookie Stickiness Policy
Function AppCookie {
New-ELBAppCookieStickinessPolicy -LoadBalancerName $Global:Rancher_Key_Lab -PolicyName ‘SessionName’ -CookieName ‘CookieName’
Set-ELBLoadBalancerPolicyOfListener -LoadBalancerName $Global:Rancher_Key_Lab -LoadBalancerPort 80 -PolicyNames ‘SessionName’
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
$ip1 = @{ IpProtocol="tcp"; FromPort="22"; ToPort="22"; IpRanges="203.0.113.25/32" }
$ip2 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges="203.0.113.25/32" }
$ip3 = @{ IpProtocol="icmp"; FromPort="-1"; ToPort="-1"; IpRanges="203.0.113.25/32" }
$ip4 = @{ IpProtocol="udp"; FromPort="500"; ToPort="500"; IpRanges="203.0.113.25/32" }
$ip5 = @{ IpProtocol="udp"; FromPort="4500"; ToPort="4500"; IpRanges="203.0.113.25/32" }
$ip6 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="203.0.113.25/32" }
$ip7 = @{ IpProtocol="tcp"; FromPort="8080"; ToPort="8080"; IpRanges="203.0.113.25/32" }
$ip8 = @{ IpProtocol="tcp"; FromPort="443"; ToPort="443"; IpRanges="203.0.113.25/32" }

Grant-EC2SecurityGroupIngress -GroupId $Global:securityGroupId -IpPermission @( $ip1, $ip2, $ip3, $ip4, $ip5, $ip6, $ip7, $ip8)
($Global:securityGroupId | Get-EC2SecurityGroup).IpPermissions  
}
# Create EC2 Instance
Function createServer {
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
            #ImageId = $Global:ImageID.ImageId
			ImageId = 'ami-996372fd'
            MinCount = 1
            MaxCount = 1
            #InstanceType = $Global:InstanceType
            InstanceType = "t2.micro"
            KeyName = $Global:Rancher_Key_Lab
            SecurityGroupId = $Global:securityGroupId
            UserData = $userdataBase64Encoded
            Region = $Global:Region.RegionName
            SubnetId = $Global:pus1aId 
			#AssociatePublicIP =  $True
            #BlockDeviceMapping = $blockDeviceMapping # see docs..
        }
$newInstances = New-EC2Instance @parameters
$a = Get-EC2InstanceStatus
$Global:instanceId = $a.InstanceId
}

Function CleanUp {
Remove-EC2Vpc $Global:vpcId -Confirm
Remove-EC2KeyPair $Global:Rancher_Key_Lab -Confirm
Remove-EC2SecurityGroup -GroupName $Global:createSG -Confirm
}

Function Menu {
$Global:Rancher_Key_Lab = "RancherLab"
$Global:createSG = "RancherSG"
$Global:Outpath = "C:\Jedi\PowerShell\Rancher"
# Select a AWS Region of choice
$Global:RegionArray = (Get-EC2Region)
$Global:Region = $Global:RegionArray | Select-Object RegionName | Out-GridView -PassThru

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
Menu
#Cleanup
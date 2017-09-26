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
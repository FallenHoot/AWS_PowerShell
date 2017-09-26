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

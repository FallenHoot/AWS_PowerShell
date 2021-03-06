
#This script will be executed on a new instance as described in exercise 2 of chapter 3  

#Set default region for scripts run on the instance
Set-DefaultAWSRegion us-east-1

#Enable PowerShell remoting so we run remote commands
Enable-PSRemoting 

#Enable remote WMI calls so we can administer and monitor the instance remotely
Get-NetFirewallRule | Where { $_.DisplayName -like "Windows Management Instrumentation *" } | Enable-NetFirewallRule 


# Login to AWS Subscription
Function Login_to_AWS {
If ( (Get-ExecutionPolicy) -ne "RemoteSigned")
{
set-ExecutionPolicy RemoteSigned -Scope Process -Force
}


If (!(Import-Module AWSPowerShell)){ Import-Module AWSPowerShell }
#If (!(Import-Module SSMDevOps)){ Import-Module SSMDevOps }

#Set-AWSCredential -AccessKey ###### -SecretKey ###### -StoreAs ECS_Zach
Initialize-AWSDefaults
Get-AWSCredential -ListProfileDetail
$Global:LocalPC_ExteralIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
}
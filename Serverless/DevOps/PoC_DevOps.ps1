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

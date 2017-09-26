Function Auto_StartEc2Instances
{
$functionname = Get-LMFunctionList -Region $Global:Region.RegionName | Select-Object -First 1

Get-LMFunction -Region $Global:Region.RegionName -FunctionName $functionname.FunctionName
        "Function Exists - trying to update"
        try {
    $zipFilePath = "C:\Jedi\PowerShell\Lamda\lambda_start_stop_ec2\StartEC2Instances.zip"
    $zipFileItem = Get-Item -Path $zipFilePath
    $fileStream = $zipFileItem.OpenRead()
    $memoryStream = New-Object System.IO.MemoryStream
    $fileStream.CopyTo($memoryStream)

    Update-LMFunctionCode -Region $Global:Region.RegionName -FunctionName $functionname.FunctionName -ZipFilename $zipFilePath
}
finally {
    $fileStream.Close()
}}

Function LM_StopEc2Instances
{
$functionname2 = Get-LMFunctionList -Region $Global:Region.RegionName | Select-Object -Skip 1 | Select-Object -First 1

Get-LMFunction -Region $Global:Region.RegionName -FunctionName $functionname2.FunctionName
        "Function Exists - trying to update"
        try {
    $zipFilePath = "C:\Jedi\PowerShell\Lamda\lambda_start_stop_ec2\StopEC2Instances.zip"
    $zipFileItem = Get-Item -Path $zipFilePath
    $fileStream = $zipFileItem.OpenRead()
    $memoryStream = New-Object System.IO.MemoryStream
    $fileStream.CopyTo($memoryStream)

    Update-LMFunctionCode -Region $Global:Region.RegionName -FunctionName $functionname2.FunctionName -ZipFilename $zipFilePath

}
finally {
    $fileStream.Close()
}}


Function CW_StartEc2Instances {
Get-CWERule -Region $Global:Region.RegionName -Name StartEC2Instances
"Rule Exists - trying to update"
try {
Write-CWERule `
-Region $Global:Region.RegionName `
-Name "StartEC2Instances" `
-Description "StartEC2Instances" `
-ScheduleExpression "cron(0 8 ? * MON-FRI *)" `
-State ENABLED `
-Force

Write-CWETarget -Region $Global:Region.RegionName -Rule StartEC2Instances -Target "arn:aws:lambda:eu-central-1:872087798133:function:StartEC2Instances"

}
Catch{}
}

Function CW_StopEc2Instances {
Get-CWERule -Region $Global:Region.RegionName -Name StopEC2Instances
"Rule Exists - trying to update"
try {

Write-CWERule -Region $Global:Region.RegionName -Name "StopEC2Instances" -Description "StopEC2Instances" -ScheduleExpression "cron(0 18 ? * MON-FRI *)" -State ENABLED -Force

Write-CWETarget -Region $Global:Region.RegionName -Rule StopEC2Instances -Target "arn:aws:lambda:eu-central-1:872087798133:function:StartEC2Instances"
}
Catch{}
}

Remove-CWERule -Region $Global:Region.RegionName -Name StopEC2Instances2 -Force

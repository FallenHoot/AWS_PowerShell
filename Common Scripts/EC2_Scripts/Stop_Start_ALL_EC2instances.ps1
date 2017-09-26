#Stop ALL EC2Instance
@(Get-EC2Instance) | % {$_.RunningInstance} | % {Stop-EC2Instance $_.InstanceId}

#Start ALL EC2Instance
@(Get-EC2Instance) | % {$_.RunningInstance} | % {Start-EC2Instance $_.InstanceId}
Function AutoScalingGroup {
$Global:LaunchConfigurationName = $Global:AutoScalingTag
New-ASLaunchConfiguration -LaunchConfigurationName $Global:LaunchConfigurationName -InstanceType "t2.micro" -ImageId "ami-489f8e2c" -SecurityGroup "$Global:securityGroup2Id"

$Global:AutoScalingGroupName = $Global:AutoScalingTag
New-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName -LaunchConfigurationName $Global:LaunchConfigurationName -MinSize 2 -MaxSize 6 -AvailabilityZone @($Global:PS1AZ, $Global:PS2AZ)
$AutoScalingResult = Get-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName
}
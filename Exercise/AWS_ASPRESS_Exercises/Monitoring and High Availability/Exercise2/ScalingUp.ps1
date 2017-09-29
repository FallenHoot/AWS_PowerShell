
#This script will resize an instance by making a copy and deleting the original   

Param(
    [string][Parameter(Mandatory=$true)] $InstanceId,
    [string][Parameter(Mandatory=$true)] $NewInstanceType
)

Edit-EC2InstanceAttribute -InstanceId $InstanceId -InstanceType $NewInstanceType

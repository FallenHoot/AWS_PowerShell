
#Add EC2 Tags
Function Add-EC2Tag 
{

Param (
      [string][Parameter(Mandatory=$True)]$key,
      [string][Parameter(Mandatory=$True)]$value,
      [string][Parameter(Mandatory=$True)]$resourceId
      )

    $Tag = New-Object amazon.EC2.Model.Tag
    $Tag.Key = $Key
    $Tag.Value = $value

    New-EC2Tag -ResourceId $resourceId -Tag $Tag | Out-Null

	## Use the following to add tags
	#Add-EC2Tag -key Name -value $Global:VPCTag -resourceId $Global:vpcId

}

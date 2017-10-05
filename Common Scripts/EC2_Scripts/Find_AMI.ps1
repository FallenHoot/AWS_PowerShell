# Find AWS Image

# Filter the images by name
Get-EC2Image -Region $Global:Region.RegionName -Filter @{"Name"="name";"Value"="*OpenVPN Access Server*"}

# Filter the image by name and select newest image
((Get-EC2Image -Region $Global:Region.RegionName -Filter @{"Name"="name";"Value"="*OpenVPN Access Server*"}
 | sort -Property CreationDate -Descending)[0]).imageid

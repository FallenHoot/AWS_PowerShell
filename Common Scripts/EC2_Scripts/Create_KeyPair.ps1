# Create KeyPair
Function createKeyPair {
#create a KeyPair, this is used to encrypt the Administrator password.
$keypair = New-EC2KeyPair -KeyName $Global:KeyPairName
"$($keypair.KeyMaterial)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem"
"KeyName: $($keypair.KeyName)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
"KeyFingerprint: $($keypair.KeyFingerprint)" | out-file -encoding ascii -filepath "$Global:Outpath\$Global:KeyPairName.pem" -Append
}

$VPC = New-EC2VPC -CidrBlock "192.168.0.0/16"
$AvailabilityZone1 = "US-EAST-1a"
$AvailabilityZone2 = "US-EAST-1a"
$PrimarySubnet = New-EC2Subnet -vpcid $vpc.vpcid -cidrBlock "192.168.5.0/24" -AvailabilityZone $AvailabilityZone1
$StandbySubnet = New-EC2Subnet -vpcid $vpc.vpcid -cidrBlock "192.168.6.0/24" -AvailabilityZone $AvailabilityZone2
New-RDSDBSubnetGroup -DBSubnetGroupName "MySubnetGroup" -DBSubnetGroupDescription "Pair of Subnets for RDS" -SubnetIDS $PrimarySubnet.SubnetID,$StandbySubnet.SubnetID
RDSGroupID = New-EC2SecurityGroup -vpcid $vpc.vpcid -GroupName "RDS" -GroupDescription "RDS Instances"

$VPCFilter = New-Object Amazon.EC2.Model.Filter
$VPCFilter.Name = "VPC-ID"
$VPCFilter.Value = $VPC.vpcid
$GroupFilter = New-Object Amazon.EC2.Model.Filter
$GroupFilter.Name = "Group-Name"
$GroupFilter.Value = "default"
$DefaultGroup = Get-EC2SecurityGroup -Filter $VPCFilter, $GroupFilter
$DefaultGroup = New-Object Amazon.EC2.Model.UserIdGroupPair
$DefaultGroupPair.GroupId = $DefaultGroup.GroupId
$SQLServerRule = New-Object Amazon.EC2.Model.IpPermission
$SQLServerRule.IpPermission = "TCP"
$SQLServerRule.FromPort = "1433"
$SQLServerRule.ToPort = "1433"
$SQLServerRule.UserIdGroupPair "DefaultGroupPair"
Grant-EC2SecurityGroupIngress -GroupId $RDSGroupID -IpPermission $SQLServerRule
$MySQLRule = New-Object Amazon.EC2.Model.IpPermission
$MySQLRule.IpPermission = "TCP"
$MySQLRule.FromPort = "3306"
$MySQLRule.ToPort = "3306"
$MySQLRule.UserIdGroupPair "DefaultGroupPair"
Grant-EC2SecurityGroupIngress -GroupId $RDSGroupID -IpPermission $MySQLRule

# Engine is defined as type of databases for RDS
# Get-RDSDBEngineVersion | Format-Table
# aurora - Only one version of Aurora
# mysql - Only one version of MySQL
# mariadb - Only one version of MariaDB
# postgres - Only one version of Postgres
# oracle-se1 - Oracle Standard Edition One
# oracle-se - Oracle Standard Edition
# oracle-ee - Oracle Enterprise Edition
# sqlserver-ex - SQL Server Express
# sqlserver-web - SQL Server Web Express
# sqlserver-se - SQL Server Standard Edition
# sqlserver-ee - SQL Server Enterprise Edition

New-RDSDBInstance -DBInstanceIdentifier "SQLServer01" 
-Engine "sqlserver-ex" 
-AllocatedStorage "20" 
-DBInstanceClass "db.t1.micro" 
-MasterUsername "sa" 
-MasterUserPassword "password" 
-DBSubnetName "MySubnetGroup" 
-VpcSecurityGroupIds $GroupId
-MultiAZ $True

#-EngineVersion
#-AutoMinorVersionUpgrade
#-AvailabilityZone
#-IOPS
#-PreferredMaintenanceWindow
#-PreferredBackupWindow
#-BackupRetentionPeriod
#-PubliclyAcessible

# Check DBInstance Status = Running
(Get-RDSDBInstance -DBInstanceIdentifier "SQLServer01").DBInstanceStatus

# Get DBConnection String
(Get-RDSDBInstance -DBInstanceIdentifier "SQLServer01").Endpoint.Address

# If you need to add anything to the instance after it has been created
# Edit-RDSDBInstance -DBInstanceIdentifier "SQLServer01"

# Delete an instance
# Remove-RDSDBInstance -DBInstanceIdentifier "SQLServer01" -FinalDBSnapshotIdentifier "SQLServer01-Final-Snapshot" -Force

$Topic = New-SNSTopic -Name "RDSTopic"
Connect-SNSNotification -TopicArn $Topic -Protocol "email" -Endpoint "Zachery.Olinske@evry.com"
New-RDSEventSubscription -SubscriptionName "MyRDSSubscription" -SnsTopicARN $Topic -SourceType "db-instance" -SourceIds "SQLServer01" 

# Add another RDS Server
Add-RDSSourceIdentifierToSubscription -SubscriptionName "MyRDSSubscription" -SourceIdentifier "sqlserver02"


# Read Replica (Is not a HA, and can't be taken as a backup. Max 5 replicas)
New-RDSDBInstanceReadReplica -DBInstanceIdentifier "MySQL01RR" -SourceDBInstanceIdentifier "MySQL01"

# Convert to Statalone RDS to Backup
Convert-RDSReadReplicaToStandalone -DBInstanceIdentifier "MySQL01RR"



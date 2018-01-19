import boto3
# Enter the region your instances are in. Include only the region without specifying Availability Zone; e.g., 'us-east-1'
region = 'eu-central-1'
# Enter your instances here: ex. ['i-0273922b3cc77c6d6', 'i-0aa3d51774cb0b376']
instances = ['i-0273922b3cc77c6d6']
instances2 = ['i-0aa3d51774cb0b376']

def lambda_handler(event, context):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.stop_instances(InstanceIds=instances)
    ec2.stop_instances(InstanceIds=instances2)
    print 'stopped your instances: ' + str(instances) + str(instances2)
	
	
	
	

instances = ['i-0271545389374ae0c']
instances2 = ['i-05c06088a7332af0e']
instances3 = ['i-063b51242cf8b8b29']
instances4 = ['i-0ba877750b54bce51']
instances5 = ['i-0fcb23f06ef54c722']
instances6 = ['i-0fded83546473a8dd']

def lambda_handler(event, context):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.stop_instances(InstanceIds=instances)
    ec2.stop_instances(InstanceIds=instances2)
	ec2.stop_instances(InstanceIds=instances3)
    ec2.stop_instances(InstanceIds=instances4)
	ec2.stop_instances(InstanceIds=instances5)
    ec2.stop_instances(InstanceIds=instances6)
    print 'stopped your instances: ' + str(instances) + str(instances2) + str(instances3) + str(instances4)+ str(instances5)+ str(instances6)
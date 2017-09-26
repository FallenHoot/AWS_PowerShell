import boto3
# Enter the region your instances are in. Include only the region without specifying Availability Zone; e.g., 'us-east-1'
region = 'eu-central-1'
# Enter your instances here: ex. ['i-0273922b3cc77c6d6', 'i-0aa3d51774cb0b376']
instances = ['i-0273922b3cc77c6d6']
instances2 = ['i-0aa3d51774cb0b376']

def lambda_handler(event, context):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.start_instances(InstanceIds=instances)
    ec2.start_instances(InstanceIds=instances2)
    print 'stopped your instances: ' + str(instances) + str(instances2)
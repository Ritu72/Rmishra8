#!/bin/bash
export AWS_PAGER=""
# Reuse all the code from mp1 - remove the RDS content, no need for that in this project

SGID=$(aws ec2 describe-security-groups --query 'SecurityGroups[1].[GroupId]')
SUBNETID1=$(aws ec2 describe-subnets --query 'Subnets[0].[SubnetId]')
SUBNETID2=$(aws ec2 describe-subnets --query 'Subnets[1].[SubnetId]')

# This would reterive the first two subnets and store their values in bash array
#SUBNETARRAY=($(aws ec2 describe-subnets --query 'Subnets[0:2:1].[SubnetId]' --output.txt))
#Additional way is with bash arrays
#SUBNETARRAY=($(aws ec2 describe-subnets --query 'Subnets[*].[SubnetId]' --output.txt))
#echo ${SUBNETARRAY[0]} 
aws ec2 run-instances --image-id $1 --instance-type $2 --count $3 --subnet-id $SUBNETID1 --key-name $4 --security-group-ids $SGID --user-data $5 --iam-instance-profile Name=$8

IDS=$(aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name==`pending`].InstanceId')

#AWS Ec2 waiters
aws ec2 wait instance-running --instance-ids $IDS
#IDSARRAY=( $(echo $IDS))
IDSARRAY=($IDS)
 
#creating the Target Groups 
echo creating the target groups
VPCID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId')
aws elbv2 create-target-group --name $6 --protocol HTTP --port 3300 --vpc-id $VPCID --health-check-protocol HTTP --health-check-port 3300 --target-type instance
echo target groups creation completed

# Need Code to register Targets to Target Group (your instance IDs)
TGARN=$(aws elbv2 describe-target-groups --query 'TargetGroups[0].TargetGroupArn')
echo register Targets to Target Group
for ID in ${IDSARRAY[@]};
do
aws elbv2 register-targets --target-group-arn $TGARN --targets Id=$ID 
done
echo Targets registered is completed

# Need code to create an ELB 
echo creating Load Balancer
aws elbv2 create-load-balancer --name $7 --subnets $SUBNETID1 $SUBNETID2 --security-groups $SGID  

# Need wait for the operations to complete 
aws elbv2 wait load-balancer-available --names $7 
echo Load Balancer creation is completed
# creating the  ELB listener (where you attach the target-group ARN)
# Query for ELB arn
ELBARN=$(aws elbv2 describe-load-balancers --name $7 --query 'LoadBalancers[0].LoadBalancerArn')
echo creating ELB listener 
aws elbv2 create-listener --load-balancer-arn $ELBARN --protocol HTTP --port 3300 --default-actions Type=forward,TargetGroupArn=$TGARN
echo ELB listener attach to target group is completed

# Use the AWS CLI to Create a S3 Bucket
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/mb.html
# code to create S3 bucket
aws s3 mb s3://${11}
echo s3 bucket is created
# Creating the DynamoDB Table for mp2 project
aws dynamodb create-table --table-name ${10} \
    --attribute-definitions AttributeName=RecordNumber,AttributeType=S AttributeName=Email,AttributeType=S \
    --key-schema AttributeName=Email,KeyType=HASH AttributeName=RecordNumber,KeyType=RANGE --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --stream-specification StreamEnabled=TRUE,StreamViewType=NEW_AND_OLD_IMAGES
echo table is created

# Create SNS topic (to subscribe the users phone number to)
# Use the AWS CLI to create the SNS
aws sns create-topic --name $9
echo sns is created

# Install ELB and EC2 instances here -- remember to add waiters and provide and --iam-instance-profile so that your EC2 instances have permission to access SNS, S3, and DynamoDB
# Sample
#aws ec2 run-instances --image-id $1 --instance-type $2 --count $3 --subnet-id $SUBNETID1 --key-name $4 --security-group-ids $SGID --user-data $5


#!/bin/bash

# Make extensive use of: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/index.html
# Adding URLs of the syntax above each command

IDS=$(aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name==`running`].InstanceId')
IDSARRAY=( $(echo $IDS))

#DBIDS=$(aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`available`].DBInstanceIdentifier')
#DBIDSARRAY=( $(echo $DBIDS))

ELBARN=$(aws elbv2 describe-load-balancers --name $7 --query 'LoadBalancers[0].LoadBalancerArn')
LISTNERARN=$(aws elbv2 describe-listeners --load-balancer-arn $ELBARN --query 'Listeners[0].ListenerArn')

#echo Destroying the DB instance and read the replica successfully
#for DBID in ${DBIDSARRAY[@]};
#do
#aws rds delete-db-instance --db-instance-identifier $DBID --skip-final-snapshot
#aws rds wait db-instance-deleted --db-instance-identifier $DBID
#done
echo Deleting the EC2 instances
aws ec2 terminate-instances --instance-ids $IDS
aws ec2 wait instance-terminated --instance-ids $IDS
echo Ec2 are terminated successfully

TGARN=$(aws elbv2 describe-target-groups --query 'TargetGroups[0].TargetGroupArn')
IDTERMINATED=$(aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name==`terminated`].InstanceId')
IDSARRAY=( $(echo $IDTERMINATED))
echo Deregistering the targets from the target group
for ID in ${IDSARRAY[@]};
do
aws elbv2 deregister-targets --target-group-arn $TGARN --targets Id=$ID
#aws elbv2 wait target-deregistered --target-group-arn $TGARN --targets Id=$ID
done

echo Deregistering is successfully completed

aws elbv2 delete-listener --listener-arn $LISTNERARN
echo The listener is removed from the load balancer

echo Deleting the target group
aws elbv2 delete-target-group --target-group-arn $TGARN
echo target group is successfully removed

echo Deleting the Load Balancer
aws elbv2 delete-load-balancer --load-balancer-arn $ELBARN
echo The load balancer is removed

echo deleting the SNS Topic and Subscription
TOPICARN=$(aws sns list-topics --query 'Topics[0].TopicArn')
SUBARN=$(aws sns list-subscriptions-by-topic --topic-arn $TOPICARN --query 'Subscriptions[0].SubscriptionArn')
aws sns unsubscribe --subscription-arn $SUBARN
aws sns delete-topic --topic-arn $TOPICARN
echo Sns Topic and Subscription successfully deleted

echo Deleting the S3 Bucket 
S3BKTNAME=$(aws s3api list-buckets --query 'Buckets[0].Name')
aws s3 rm s3://$S3BKTNAME --recursive
aws s3 rb s3://$S3BKTNAME
echo s3 bucket is successfully deleted 

echo destroying the dynamodb database table
DYODBNAME=$(aws dynamodb list-tables --query 'TableNames[0]')
aws dynamodb delete-table --table-name $DYODBNAME
aws dynamodb wait table-not-exists --table-name $DYODBNAME
echo The DynamoDB table $DYODBNAME is successfully removed from database
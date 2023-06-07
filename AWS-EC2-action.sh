#!/bin/bash

# Check if the first parameter is either "start" or "stop"
check_action()
{
    startstop=$(echo "$action" | tr '[:lower:]' '[:upper:]') # Convert to lowercase for case-insensitive comparison
    if [[ "$startstop" != "START" && "$startstop" != "STOP" ]]; then
        echo "Action must be either 'Start' or 'Stop'"
        exit 1
    fi
}

check_region()
{
    valid_regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

    # Check if the selected region is valid
    if [[ ! $valid_regions =~ (^|[[:space:]])$region($|[[:space:]]) ]]; then
        echo "Invalid region specified: $region"
        exit 1
    fi

}
# Check the current configured region
set_region()
{
    current_region=$(aws configure get region)

    # Switch to the specified region if it's different from the current configured region
    if [[ $region != $current_region ]]; then
        echo "Temporarily switching to region: $region"
        aws configure set region $region
    fi
}

# Switch back to the original region if it was changed
restore_region()
{
    if [[ $region != $current_region ]]; then
        echo "Switching back to the original region: $current_region"
        aws configure set region $current_region
    fi
}

# Function to start the EC2 instance
start_instance() 
{
    aws ec2 start-instances --instance-ids "$instance_id"
    if [[ $? -eq 0 ]]; then
        echo "EC2 instance $instance_id started."
    else
        echo "Error starting instance $instance_id"
    fi
}

# Function to stop the EC2 instance
stop_instance() 
{
    aws ec2 stop-instances --instance-ids "$instance_id"
    if [[ $? -eq 0 ]]; then
        echo "EC2 instance $instance_id stopped."
    else
        echo "Error starting instance $instance_id"
    fi
}

# Get the current configured aws user
get_aws_username()
{
    username=$(aws iam get-user --query 'User.UserName' --output text)
    echo "$username"
}

if [ $# -ne 3 ]; then
    echo "Usage: $0 <region> <instance-id> <START|STOP>"
    exit 1
fi

aws_user="$(get_aws_username)"

# Get the region, instance ID, and action from command-line arguments
region=$1
instance_id=$2
action=$3

check_region
check_action

set_region

# Perform the specified action
case $startstop in
    'START')
                start_instance
                ;;
    'STOP')
                stop_instance
                ;;
    *)
                echo "Invalid action. Possible actions: START or STOP. ($startstop)"
                restore_region
                exit 1
esac

restore_region

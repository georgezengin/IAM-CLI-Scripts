#!/bin/bash

# Function to create an EC2 instance
create_instance() {
    echo "Creating an EC2 instance..."
    echo "Gather the details for the following parameters: Instance_type, AMI ID, security_group_id, key_pair_name and subnet_id"

    read -r -p "Step 1/5 - Enter the instance type (e.g., t2.micro): " instance_type
    if [ -z "$instance_type" ]; then
        exit
    fi
    read -r -p "Step 2/5 - Enter the AMI ID (e.g., ami-123456789): " ami_id
    if [ -z "$ami_id" ]; then
        exit
    fi
    read -r -p "Step 3/5 - Enter the security group ID: " security_group_id
    if [ -z "$security_group_id" ]; then
        exit
    fi

    read -r -p "Step 4/5 - Enter the key pair name: " key_pair_name
    if [ -z "$key_pair_name" ]; then
        exit
    fi
    read -r -p "Step 5/5 - Enter the subnet ID: " subnet_id
    if [ -z "$subnet_id" ]; then
        exit
    fi

    result=$(aws ec2 run-instances --image-id "$ami_id" --instance-type "$instance_type" --security-group-ids "$security_group_id" \
        --key-name "$key_pair_name" --subnet-id "$subnet_id")
    if [ $? -eq 0 ]; then
        echo "Instance Run initiated."
        exit
    else
        echo "Instance Launch error, couldn't launch requested instance"
        exit 1
    fi
}

# Function to delete an EC2 instance
delete_instance() {
    echo "Terminating an EC2 instance..."
    
    # Get a list of instances
    instance_list=$(aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId, State.Name]" --output text)
    if [[ -z "$instance_list" ]]; then
        echo "No instances found."
        exit 1
    fi
    # Print the list of instances
    echo "Instances:"
    echo "$instance_list"
    select instance_id in $instance_list; do
        if [ -n "$instance_id" ]; then
            echo "Terminating EC2 instance $instance_id..."
            result=$(aws ec2 terminate-instances --instance-ids "$instance_id")
            if [ $? -eq 0 ]; then    
                echo "$result"
                echo "... Termination initiated!."
            else
                echo "Termination attempt of instance $instance_id seems to have failed! Please check with your administrator."
                exit 1
            fi
            break
        else
            echo "Not a good choice, please try again later."
        fi
    done
}

get_ec2_list()
{
    instance_list=$(aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId, State.Name]" --output text)
    
    # Check if there are any instances
    if [[ -z "$instance_list" ]]; then
        echo "No EC2 instances found for user $aws_user."
    else
        echo "Instances found:"
        echo "$instance_list"    
    fi
}


check_usage()
{
    # Check if an AWS user is provided as a parameter
    if [ -z "$1" ]; then
        echo "Usage: $0"' <AWSUserID>'
        echo "AWS User parameter is missing."
        exit 1
    fi
}

get_aws_username()
{
    username=$(aws iam get-user --query 'User.UserName' --output text)
    echo "$username"
}

check_usage "$1"
curr_user="$(get_aws_username)"
aws_user="$1"

if ! aws iam get-user --user-name "$aws_user" &> /dev/null; then
    echo "User $aws_user does not exist in AWS (supervised to $curr_user)"
    exit 1
fi

echo "Current configured user in AWS CLI is $curr_user"
while true; do
    echo ""
    echo "$0"' - EC2 actions for User='"$aws_user"
    echo ""
    read -r -p "Choose an action for EC2 Instances for user $aws_user -- [C]reate, [D]elete, [L]ist, [Q]uit --> " action
    echo ""
    action=$(echo "$action" | tr '[:lower:]' '[:upper:]')

    case $action in
        'C')
            create_instance            
            ;;
        'D')
            delete_instance
            ;;
        'L')
            get_ec2_list
            ;;
        'Q')
            echo ""
            echo "Good bye, have a nice day!"
            echo ""
            break
            ;;
        *)
            echo "*** Me-non-comprende, say again ??? ***"
            echo ""
            ;;
    esac
done

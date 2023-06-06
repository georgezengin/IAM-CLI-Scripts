#!/bin/bash

get_instance_types()
{
    instance_types=$(aws ec2 describe-instance-types --query "InstanceTypes[?contains(InstanceType, 't2') || \
                                                                             contains(InstanceType, 't3')].InstanceType" --output text | \
                    tr \[:space:\] '\n' | sort)
    if [ -n "$instance_types" ]; then
        PS3="Step 1/5 - Enter the instance type (e.g., t2.micro): " 
        select instance_type in $instance_types; do
            if [ -z "$instance_type" ]; then
                exit 1
            fi
        done
    fi
}

get_ami_id()
{

}

create_instance() {
    echo "Creating an EC2 instance..."
    echo "Gather the details for the following parameters: Instance_type, AMI ID, security_group_id, key_pair_name and subnet_id"
    get_instance_types
    if [ -z "$instance_type" ]; then
        exit
    fi

    get_ami_id
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

delete_instance() {
    echo "Terminating an EC2 instance..."
    
    instance_list=$(aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId, State.Name]" --output text)
    if [[ -z "$instance_list" ]]; then
        echo "No instances found."
        exit 1
    fi
    echo "Instances:"
    #echo "$instance_list"
    PS3="Select instance id to delete: "
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
    if [[ -z "$instance_list" ]]; then
        echo "No EC2 instances found for user $aws_user."
    else
        echo "Instances found:"
        echo "$instance_list"    
    fi
}

check_usage()
{
    if [ -z "$1" ]; then
        echo "Usage: $0"' <AWSUserID>'
        echo "AWS User parameter is missing."
        exit 1
    fi
}

select_profile()
{
    entries=$(echo "$aws_profiles" | wc -l)

    if [ "$entries" -eq 1 ]; then
        usr_profile="$aws_profiles"
    else
        PS3="Select profiles for user: $aws_user"
        select usr_profile in $aws_profiles; do
            if [ -n "$usr_profile" ]; then
                echo "Selected Profile is [$usr_profile]"
            else
                echo "No profile selected."
            fi
        done
    fi
}

select_arn_role()
{
    entries=$(echo "$roles" | wc -l)

    if [ "$entries" -eq 1 ]; then
        usr_role="$roles"
    else
        PS3="Select Role for user: $aws_user in profile $usr_profile"
        select usr_role in $roles; do
            if [ -z "$usr_role" ]; then
                echo "No role selected."
            fi
        done
    fi
    echo "Role is [$usr_role]"
}

get_arn_user()
{
    if [ -n "$usr_profile" ]; then
        user_arn=$(aws configure get --profile "$usr_profile" aws_user_arn)
    
        # If the user ARN is not empty, check the roles associated with the user
        if [[ -n "$user_arn" ]]; then
            echo "Roles for $user_arn:"
            
            # List the roles associated with the user
            roles=$(aws iam list-roles --query "Roles[?AssumeRolePolicyDocument.Statement[].Principal.AWS == '$user_arn'].RoleName" --output text)
            
            # Print the roles
            #echo "$roles"
        else
            echo "No user ARN configured."
        fi
    fi
}

get_aws_username()
{
    username=$(aws iam get-user --query 'User.UserName' --output text)
    echo "$username"
}

get_profiles_list()
{
    aws_profiles=$(aws configure list-profiles)
    #echo "$(aws_profiles)"
}

aws_chk_user()
{
    if ! aws iam get-user --user-name "$aws_user" &> error.aws; then #/dev/null; then
        echo "User $aws_user does not exist in AWS."
        echo "Error: $(cat error.aws)"
        exit 1
    fi
}

#check_usage "$1"
aws_user="$(get_aws_username)"
#aws_user="$1"
aws_chk_user
get_profiles_list
select_profile
get_arn_user
select_arn_role


echo "Current configured user in AWS CLI is $aws_user"
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

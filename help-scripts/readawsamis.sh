#!/bin/bash

# Retrieve the 10 most recently used AMIs with their descriptions
image_info=$(aws ec2 describe-images --owners amazon --filters "Name=architecture,Values=x86_64" "Name=root-device-type,Values=ebs" "Name=virtualization-type,Values=hvm" "Name=state,Values=available" "Name=usage-operation,Values=*RunInstances" --query "Images[?contains(Name, 'Amazon Linux') || contains(Name, 'Ubuntu')].[ImageId, Name]" --output text)

echo "$image_info"
# Store the image IDs and descriptions in separate arrays
readarray -t image_ids <<< "$(echo "$image_info" | awk '{print $1}')"
readarray -t image_descriptions <<< "$(echo "$image_info" | awk '{$1=""; print $0}')"

# Display a menu to select an AMI
PS3="Select an AMI: "
select ami_index in "${!image_descriptions[@]}"; do
    if [[ "$ami_index" =~ ^[0-9]+$ ]] && (( ami_index >= 1 && ami_index <= ${#image_ids[@]} )); then
        selected_ami_id=${image_ids[$((ami_index - 1))]}
        selected_ami_description=${image_descriptions[$((ami_index - 1))]}
        break
    else
        echo "Invalid option. Please try again."
    fi
done

echo "Selected AMI ID: $selected_ami_id"
echo "Selected AMI Description: $selected_ami_description"

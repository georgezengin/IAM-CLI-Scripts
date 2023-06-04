#!/bin/bash

# Get the list of profiles
profiles=$(aws configure list-profiles)

# Loop through each profile
for profile in $profiles; do
  echo "Profile: $profile"
  
  # Get the configured user ARN
  user_arn=$(aws configure get --profile "$profile" aws_user_arn)
  
  # If the user ARN is not empty, check the roles associated with the user
  if [[ -n "$user_arn" ]]; then
    echo "Roles for $user_arn:"
    
    # List the roles associated with the user
    roles=$(aws iam list-roles --query "Roles[?AssumeRolePolicyDocument.Statement[].Principal.AWS == '$user_arn'].RoleName" --output text)
    
    # Print the roles
    echo "$roles"
  else
    echo "No user ARN configured."
  fi
  
  echo "----------------------"
done

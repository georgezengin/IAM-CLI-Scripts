#!/bin/bash

# Get the current AWS user ARN and Username
user_arn=$(aws sts get-caller-identity --query "Arn" --output text)
username=$(aws sts get-caller-identity --query "Arn" --output text | cut -d/ -f2)

# Check if the user ARN matches the root user ARN format
if [[ $user_arn == arn:aws:iam::*:root ]]; then
  echo "The current user ($username) is the root user."
else
  echo "The current user ($username) is not the root user."

  # Attempt to get the root user's username
  root_username=$(aws iam get-user --user-name root --query "User.UserName" --output text 2>/dev/null)
  
  if [[ $? -eq 0 ]]; then
    echo "Root user username: $root_username"
  else
    echo "Unable to retrieve the root user's information."
  fi
fi

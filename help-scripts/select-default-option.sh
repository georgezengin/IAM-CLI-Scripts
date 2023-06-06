#!/bin/bash

options=("Option 1" "Option 2" "Option 3")
default_option=2

echo "Please choose an option:"

# Prepare the default option prompt
default_prompt=""
if [[ $default_option -gt 0 && $default_option -le ${#options[@]} ]]; then
  default_prompt=" (${options[$default_option - 1]})"
fi

# Display the options
PS3="Enter your choice${default_prompt}: "
select choice in "${options[@]}"; do
  # If the choice is empty, set it to the default option
  if [[ -z $choice ]]; then
    choice=${options[$default_option - 1]}
  fi

  break
done

echo "You chose: $choice"

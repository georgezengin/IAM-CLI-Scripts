#!/bin/bash

# Get current configured region
get_region()
{
    current_region=$(aws configure get region)
    echo "Current region: [$current_region]"
    # Get list of available AWS regions
    
    default_choice='N'
    choice='N'
    while true; do
        read -n 1 -p "Do you want to choose another region? (Y/N)" choice
        choice=${choice:-$default_choice}  # Set default value if empty
        choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')  # Convert to lowercase
        echo ""
        case $choice in
            'Y')
                regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
                if [ -n "$regions" ]; then
                    # Prompt the user to select a region
                    echo "Available regions:"
                    PS3="Select a region (default: $current_region): "
                    select region in $regions; do
                        if [[ -n $region ]]; then
                            break
                        elif [[ -z $REPLY ]]; then
                            region=$current_region
                            break
                        else
                            echo "Invalid selection. Try again."
                        fi
                    done
                else
                    echo "Couldn't retrieve a list of regions, using currently configured region: $current_region"
                    region=$current_region
                fi
                break
                ;;
            'N')
                region=$current_region
                break
                ;;
            *)
                echo "...try again... (what did I ask after all? just a Y or N????!!!)"
                ;;
        esac
    done
}

get_instance()
{
    # Retrieve the list of EC2 instances in the selected region
    instance_list=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId, State.Name]' --region $region --output text)
    # Check if any instances are running
    if [[ -z $instance_list ]]; then
        echo "No EC2 instances found in the selected region: $region"
        exit 1
    fi

    # Prompt the user to select an instance to start/stop
    echo "Available EC2 instances in $region:"
    PS3="Select an instance: "
    select instance in $instance_list; do
        if [[ -n $instance ]]; then
            # Extract the instance ID from the selected instance
            instance_id=$(echo $instance | awk '{print $1}')
            break
        else
            echo "Invalid selection. Try again."
        fi
    done
}

get_action()
{
    # Prompt the user to select an action (start or stop)
    PS3="Select an action ([S]tart or Stop): "
    select action in "Start" "Stop"; do
        if [[ -n $action ]]; then
            break
        else
            echo "Invalid selection. Try again."
        fi
    done
}    

get_time()
{
    # Prompt the user for the time (in 24-hour format)
    read -p "Enter the time to schedule the action (HH:MM): " schedule_time
}

get_region
echo "Selected region: $region"
get_instance
echo "Selected instance: $instance_id"
get_time
echo "Requested Schedule time: $schedule_time

# Add a cron job to perform the action at the specified time
cron_job="$schedule_time * * * * /path/to/ec2_action.sh $region $instance_id $action >> AWS-EC2-schedule.log 2>&1"
(crontab -l 2>/dev/null; echo "$cron_job") | crontab -

echo "EC2 instance $instance_id will $action at $schedule_time daily."
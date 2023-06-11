#!/bin/bash

# Get current configured region
get_region()
{
    current_region=$(aws configure get region)
    echo "Current region: [$current_region]"
    
    default_choice='N'
    choice='Y'
    while true; do
        if [ -z "$current_region" ]; then
            echo '*** No region configured for current user, please choose a region'
        else
            read -n 1 -p "Do you want to choose another region? (Y/N) " choice
            choice=${choice:-$default_choice}  # Set default value if empty
            choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')  # Convert to lowercase
        fi
        echo ""

        case $choice in
            'Y')
                # Get list of available AWS regions
                regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text | tr [:space:] '\n' | sort)
                if [ -n "$regions" ]; then
                    # Prompt the user to select a region
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
    echo ""
    # Retrieve the list of EC2 instances in the selected region
    instance_list=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId, Tags[?Key==`Name`].Value | [0], State.Name]' --region $region --output text | awk '$3 == "running" {print $2 "(" $1 ")"}')
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
            instance_name=$(echo $instance | sed 's/\(([^)]*)\)//')
            instance_id=$(echo $instance | sed 's/.*(\([^)]*\)).*/\1/')
            break
        else
            echo "*** Invalid Instance selected. Try again."
        fi
    done
}

get_action()
{
    # Prompt the user to select an action (start or stop)
    echo ""
    action=''
    while true; do
        read -n 1 -p "Action to perform on instance $instance_name ? [S]tart or s[T]op (S/T): " action
        action=$(echo "$action" | tr '[:lower:]' '[:upper:]')  # Convert to lowercase
        echo ""
        case $action in
            'S')
                action="START"
                break
                ;;
            'T')
                action="STOP"
                break
                ;;
            *)
                echo "*** Invalid action. Try again."
        esac
    done
}    

get_time()
{
    # Prompt the user for the time (in 24-hour format)
    schedule_time=""
    echo ""

    while [[ -z $schedule_time ]]; do
        read -p "Enter the time to schedule the action (HH:MM): " schedule_time
        if [[ ! $schedule_time =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            echo "*** Please enter a valid time in 24-hour format."
            schedule_time=""
        fi
    done
    cron_time_mask #generate time mask for crontab
}

cron_time_mask() 
{
    hour=${schedule_time%%:*}
    minute=${schedule_time#*:}

    # Generate the cron mask for scheduling the command
    cron_mask="$minute $hour * * *"
}

get_region
echo "Selected region: $region"
get_instance
echo "Selected instance: Name=$instance_name Id=$instance_id"
get_action
echo "Selected action: $action"
get_time
echo "Requested Schedule time: $schedule_time ($cron_mask)"
echo ""

# Add a cron job to perform the action at the specified time
cron_job="$cron_mask AWS-EC2-action.sh $region $instance_id $action >> AWS-EC2-schedule.log 2>&1"
echo "CRONTAB new entry=[$cron_job]"
(crontab -l 2>/dev/null; echo "$cron_job") | crontab -

echo "EC2 instance Name:$instance_name Id:$instance_id will $action at $schedule_time daily."
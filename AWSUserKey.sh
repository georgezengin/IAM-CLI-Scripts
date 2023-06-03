#!/bin/bash

create_access_key()
{
    echo ""        
    echo "C'mon! Let's create an access key for... this... what's his name? Ah, yes, $aws_user!!!"

    result=$(aws iam create-access-key --user-name "$aws_user")
    if [ $? -eq 0 ]; then
        access_key_id=$(echo "$result" | grep -oE '"AccessKeyId": "[^"]+' | awk -F'"' '{print $4}')
        key_file="$aws_user.$access_key_id.access-key"
        echo "$result" | tee "$key_file"
        echo "*** Access key file [$key_file] created"
else
        echo "Unable to create access key. [Error $?]"
        exit 1
    fi
}


delete_access_key()
{
    echo "Getting access keys... be patient... :-Q"
    keys=$(aws iam list-access-keys --user-name "$aws_user" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    if [ -z "$keys" ]; then
        echo "No access keys found for user $aws_user."
        exit 1
    fi
    PS3="Which access key shall I delete, your highness???? "
    select key in $keys; do
        if [ -n "$key" ]; then
            echo "Surely, proceeding with the deletion of access key $key..."
            result=$(aws iam delete-access-key --user-name "$aws_user" --access-key-id "$key")
            if [ $? -eq 0 ]; then    
                #key_id=$(echo "$result" | grep -oE '"KeyPairId": "[^"]+' | awk -F'"' '{print $4}')
                key_file=$(ls -p -d $aws_user.$key.access-key | grep -v / )
                echo "Looking for key file: $key_file"
                if [ -f "$key_file" ]; then
                    read -r -p "Found file [$key_file], delete it? (Y/N)" delaction
                    delaction=$(echo "$delaction" | tr '[:lower:]' '[:upper:]')
                    if [ "$delaction" == "Y" ]; then
                        rm -f "$key_file" 2>/dev/null
                    else
                        echo "File [$key_file] not deleted, please dispose manually. Extension .deleted was added to it"
                        mv "$key_file" "$key_file.deleted" 2>/dev/null
                    fi
                fi
                echo "... and we're done!."
            else
                echo "* Error * Failed to delete the selected key-pair $key_pair_name"
                exit 1
            fi
            break
        else
            echo "Invalid choice. Please select a valid key pair."
        fi
    done
}

make_keys_file()
{
    delimiter="|"
    string=$(echo "$keys" | tr -s '[:blank:]' "$delimiter")
    words=$(echo "$string" | grep -o '[^'"$delimiter"']\+')
    rm -f "$key_file" 2>/dev/null
    for word in $words; do
        echo "$word" | tee -a "$key_file"
    done
    echo "Find the blessed keys in file $key_file, boss!"
}

get_key_list()
{
    echo ""
    keys=$(aws iam list-access-keys --user-name "$aws_user" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    if [ -z "$keys" ]; then
        echo "* Error * Couldn't get any access keys for user $aws_user"
    else
        echo "Here you are all the access keys for user $aws_user:"
        key_file="$aws_user.access-keys"
        make_keys_file #"$key_file" "$keys"
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
    echo "$0"' - Access Key actions on User='"$aws_user"
    echo ""
    read -r -p "Choose an action for access keys for user $aws_user -- [C]reate, [D]elete, [L]ist, [Q]uit --> " action
    echo ""
    action=$(echo "$action" | tr '[:lower:]' '[:upper:]')

    case $action in
        'C') # Create access key
            create_access_key
            break
            ;;

        'D') # Delete access key
            delete_access_key
            break
            ;;
            
        'L') # List access keys
            get_key_list #"$aws_user"
            break
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


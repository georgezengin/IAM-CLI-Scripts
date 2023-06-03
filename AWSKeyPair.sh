#!/bin/bash

create_key_pair()
{
    echo ""        
    echo "C'mon! Let's create an keypair for ... this... what's his name? Ah, yes, $aws_user!!!"

    read -p "Enter the key-pair name: " key_pair_name

    result=$(aws ec2 create-key-pair --key-name "$key_pair_name")

    if [ $? -eq 0 ]; then
        key_id=$(echo "$result" | grep -oE '"KeyPairId": "[^"]+' | awk -F'"' '{print $4}')
        key_file="$aws_user.$key_pair_name.$key_id.pem"
        echo "$result" | tee "$key_file"
        chmod 400 "$key_file"
        echo "*** Key-pair file [$key_file] created"
    else
        echo "Unable to create key-pair. [Error $?]"
        exit 1
    fi
}

delete_key_pair()
{
    key_pair_list=$(aws ec2 describe-key-pairs --query "KeyPairs[].KeyName" --output text)
    if [[ -z "$key_pair_list" ]]; then
        echo "No key pairs found."
        exit 1
    fi

    PS3="Select a key pair to delete: "
    select key_pair_name in $key_pair_list; do
        if [[ -n "$key_pair_name" ]]; then
            echo "Surely, proceeding with the deletion of key-pair $key..."
            result=$(aws ec2 delete-key-pair --key-name "$key_pair_name")
            if [ $? -eq 0 ]; then
                key_file=$(ls -p -d $aws_user.$key_pair_name*.pem | grep -v / )
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

make_key_pairs_file()
{
    delimiter="|"
    string=$(echo "$keypairs" | tr -s '[:blank:]' "$delimiter")
    words=$(echo "$string" | grep -o '[^'"$delimiter"']\+')
    rm -f "$key_file" 2>/dev/null
    for word in $words; do
        echo "$word" | tee -a "$key_file"
    done
    echo "Find the list of key-pairs in file $key_file, boss!"
}

get_key_list()
{
    keypairs=$(aws ec2 describe-key-pairs --query "KeyPairs[].KeyName" --output text)
    if [ -z "$keypairs" ]; then
        echo "* Error * Couldn't get any key-pairs for user $aws_user"
    else
        echo "Here you are all the key-pairs for user $aws_user:"
        key_file="$aws_user.keylist"
        make_key_pairs_file
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
        'C')
            create_key_pair
            break
            ;;

        'D')
            delete_key_pair
            break
            ;;
            
        'L')
            get_key_list
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

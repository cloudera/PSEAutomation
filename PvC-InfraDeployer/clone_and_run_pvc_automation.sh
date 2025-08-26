#!/bin/bash

set -e          # Exit immediately if a command fails
set -o pipefail # Catch errors in pipes

# Function to print a fancy banner
print_message() {
    echo ""
    echo "================================================================="
    echo "            🚀 $(echo $0: $1) 🚀          "
    echo "================================================================="
    echo ""
}

# Uncomment this section if repository cloning is required
print_message "Checking and setting up repository..."
if [ -d "pvc-automation" ]; then
    echo "Repository already exists. Pulling latest changes..."
    # cd pvc-automation
    # git reset --hard
    # git clean -fd
    # git pull origin main
else
    echo "Cloning the repository..."
    git clone https://github.com/kuldeepsahu1105/pvc-automation.git
    # cd pvc-automation
fi

# Check for pem/idrsa file in the current path
pem_file=$(find . -maxdepth 1 -type f \( -name "*.pem" -o -name "idrsa" \))
if [ -z "$pem_file" ]; then
    echo "Error: No .pem or idrsa file found in the current directory."
    exit 1
else
    echo "Found key file: $pem_file"
    cp -vf "$pem_file" "sshkey.pem" || true
    echo "Renamed $pem_file to sshkey.pem"
fi

# Check for a txt file with "license" in its name and rename it to license.txt
license_file=$(find . -maxdepth 1 -type f -name "*license*.txt")
if [ -z "$license_file" ]; then
    echo "Error: No license file found in the current directory."
    exit 1
else
    cp -vf "$license_file" license.txt || true
    echo "Renamed $license_file to license.txt"
fi

# Navigate to ansible-test directory if it exists
if [ -d "pvc-automation/ansible-test" ]; then
    echo "ansible-test directory already exists..."

    # Ensure sshkey.pem and license.txt exist before moving
    if [ -f "sshkey.pem" ] && [ -f "license.txt" ]; then
        echo "Moving sshkey.pem and license.txt to ansible-test directory..."
        cp -vf sshkey.pem license.txt pvc-automation/ansible-test/
    else
        echo "Warning: sshkey.pem or license.txt not found!"
        exit 1
    fi

    echo "Changing directory to ansible-test..."
    cd pvc-automation/ansible-test || exit 1 # Exit if cd fails

    echo "Pulling latest changes from Git..."
    git pull origin main
else
    echo "ansible-test directory does not exist!"
fi

# Prompt for username
read -p "Enter Cloudera Manager Repo Username: " cm_repo_username

# Prompt for password (input hidden)
read -s -p "Enter Cloudera Manager Repo Password: " cm_repo_password
echo "" # Newline after password input

# Export variables
export CM_REPO_USERID="$cm_repo_username"
export CM_REPO_PASSWD="$cm_repo_password"

# Confirm that variables are set
echo "Environment variables for cm_repo credentials set successfully."
echo "CM_REPO_USERID: $CM_REPO_USERID"
echo "CM_REPO_PASSWD: $CM_REPO_PASSWD"

# Execute pvc_setup.sh
print_message "Executing pvc_setup.sh..."
chmod +x pvc_setup.sh
bash ./pvc_setup.sh

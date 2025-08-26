#!/bin/bash

# Set Keycloak Server Details
KEYCLOAK_URL="https://partnerday.clouderapartners.click"
REALM="master"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
NEW_PASSWORD="changeme"
CLIENT_ID="admin-cli"

# Get Admin Access Token
ACCESS_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=$CLIENT_ID" \
    -d "username=$ADMIN_USER" \
    -d "password=$ADMIN_PASSWORD" \
    -d "grant_type=password" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "Failed to get access token. Check your credentials."
    exit 1
fi

echo "Admin token acquired."

# # Fetch users whose usernames start with "partner0__"
# USER_IDS=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=partner0__&max=100" \
#     -H "Authorization: Bearer $ACCESS_TOKEN" \
#     -H "Content-Type: application/json" | jq -r '.[].id')

# if [ -z "$USER_IDS" ]; then
#     echo "No users found with the specified username pattern."
#     exit 1
# fi

# echo "Found users: $USER_IDS"

# # Reset password for each user
# for USER_ID in $USER_IDS; do
#     curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/reset-password" \
#         -H "Authorization: Bearer $ACCESS_TOKEN" \
#         -H "Content-Type: application/json" \
#         -d '{
#             "type": "password",
#             "value": "'"$NEW_PASSWORD"'",
#             "temporary": false
#         }'
#     echo "Password reset for user ID: $USER_ID"
# done

# echo "Password reset complete for all matching users."

# Loop through usernames from partner001 to partner030
for i in $(seq -w 99 100); do
    USERNAME="partner0$i"
    echo "Processing user: $USERNAME"

    # Fetch user ID based on username
    USER_ID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$USERNAME" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.[0].id')

    # If no user found, skip
    if [ "$USER_ID" == "null" ] || [ -z "$USER_ID" ]; then
        echo "User $USERNAME not found. Skipping..."
        continue
    fi

    # Reset password for the user
    curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/reset-password" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "type": "password",
            "value": "'"$NEW_PASSWORD"'",
            "temporary": false
        }'

    echo "Password reset for user: $USERNAME"
done

echo "Password reset complete for all matching users."

# This script is used to reset the password for existing users who attended the workshop to be able to use for next one.

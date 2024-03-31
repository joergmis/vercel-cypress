#!/bin/sh -l

# Input arguments
API_TOKEN=$1
PROJECT_ID=$2
TEAM_ID=$3
CYPRESS_OPTIONS=$4

QUERY="projectId=$PROJECT_ID"
TIMEOUT=10

if [ -n "$TEAM_ID" ]; then
    QUERY="${QUERY}&teamId=${TEAM_ID}"
fi

echo "=> Fetching deployments..."

# Function to fetch and parse the most recent or specific deployment state
fetch_deployment() {
    # Fetch the response and save it to a temporary file
    TEMP_RESPONSE_FILE=$(mktemp)
    ERROR_FILE=$(mktemp)
    
    # Use curl with -f to fail on HTTP errors
    HTTP_STATUS=$(curl -s -o "$TEMP_RESPONSE_FILE" -w "%{http_code}" -X GET "https://api.vercel.com/v6/deployments?${QUERY}" -H "Authorization: Bearer ${API_TOKEN}" -f -S 2>"$ERROR_FILE")
    
    # Check if curl command succeeded
    if [ "$HTTP_STATUS" -ne 200 ]; then
        echo "Failed to fetch deployments. HTTP Status: $HTTP_STATUS"
        cat "$ERROR_FILE"
        cat "$TEMP_RESPONSE_FILE" # Print response body if available
        rm "$TEMP_RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi

    # Find the index of the deployment that matches the given GITHUB_SHA or default to 0
    if [ -z "$GITHUB_SHA" ]; then
        INDEX=0
        echo "=> Using most recent deployment"
    else
        INDEX=$(jq -r --arg GITHUB_SHA "$GITHUB_SHA" '.deployments | map(.meta.githubCommitSha) | index($GITHUB_SHA)' < "$TEMP_RESPONSE_FILE")
        echo "=> Using deployment for commit $GITHUB_SHA"
        # If no matching deployment is found, default to the first deployment
        if [ "$INDEX" = "null" ]; then
            INDEX=0
            echo "=> Using most recent deployment (github SHA $GITHUB_SHA not found)"
        fi
    fi

    # Extract each field using jq and the found index
    DEPLOYMENT_URL=$(jq -r --argjson INDEX "$INDEX" '.deployments[$INDEX].url' < "$TEMP_RESPONSE_FILE")
    DEPLOYMENT_STATE=$(jq -r --argjson INDEX "$INDEX" '.deployments[$INDEX].state' < "$TEMP_RESPONSE_FILE")
    DEPLOYMENT_READYSTATE=$(jq -r --argjson INDEX "$INDEX" '.deployments[$INDEX].readyState' < "$TEMP_RESPONSE_FILE")
    
    # Cleanup: Remove the temporary file
    rm "$TEMP_RESPONSE_FILE"
    
        echo "=> Current Deployment State: $DEPLOYMENT_STATE"
    echo "=> Ready State: $DEPLOYMENT_READYSTATE"
}


# Initial fetch to get the state of the most recent or a specific deployment
fetch_deployment

# Loop until the deployment state is READY, readyState is READY
while [ "$DEPLOYMENT_STATE" != "READY" ] || [ "$DEPLOYMENT_READYSTATE" != "READY" ]; do
    # If the deployment state or ready state is CANCELED, exit the script with a non-zero status code
    if [ "$DEPLOYMENT_STATE" = "CANCELED" ] || [ "$DEPLOYMENT_READYSTATE" = "CANCELED" ]; then
        echo "=> Deployment or ready state is canceled. Exiting..."
        exit 1
    fi

    echo "=> Deployment not ready yet. Retrying in $TIMEOUT seconds..."
    sleep $TIMEOUT
    
    fetch_deployment # Fetch and update the deployment state again
done

echo "=> Deployment is ready!"
echo "=> Found deployment URL: https://${DEPLOYMENT_URL}"

# Proceed with the Cypress tests
yarn install
export CYPRESS_BASE_URL="https://${DEPLOYMENT_URL}"
npx cypress run ${CYPRESS_OPTIONS}

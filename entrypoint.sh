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

echo "Query: $QUERY"

echo "=> Fetching deployments..."

# Function to fetch and parse the most recent or specific deployment state
fetch_deployment() {
    DEPLOYMENT_URL=$(curl -X GET "https://api.vercel.com/v6/deployments?${QUERY}" -H "Authorization: Bearer ${API_TOKEN}" | jq -r '.deployments[0].url')
    DEPLOYMENT_STATE=$(curl -X GET "https://api.vercel.com/v6/deployments?${QUERY}" -H "Authorization: Bearer ${API_TOKEN}" | jq -r '.deployments[0].state')
    DEPLOYMENT_READYSTATE=$(curl -X GET "https://api.vercel.com/v6/deployments?${QUERY}" -H "Authorization: Bearer ${API_TOKEN}" | jq -r '.deployments[0].readyState')
    
    echo "Current Deployment State: $DEPLOYMENT_STATE, Ready State: $DEPLOYMENT_READYSTATE, Ready Substate: $DEPLOYMENT_READYSUBSTATE"
}

# Initial fetch to get the state of the most recent or a specific deployment
fetch_deployment

# Loop until the deployment state is READY, readyState is READY
while [ "$DEPLOYMENT_STATE" != "READY" ] || [ "$DEPLOYMENT_READYSTATE" != "READY" ]; do
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

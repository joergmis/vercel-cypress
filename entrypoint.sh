#!/bin/sh -l

# inputs arguments
# 1 -> api token
# 2 -> project id
# 3 -> (optional) team id
# 4 -> cypress options
# 5 -> path to test results

QUERY="projectId=$2"

if [ -n "$3" ]; then
    QUERY="${QUERY}&teamId=${3}"
fi

DEPLOYMENT_URL=$(curl -X GET "https://api.vercel.com/v6/deployments?${QUERY}" -H "Authorization: Bearer $1"  | jq -r '.deployments[0].url')
echo "=> found deployment url: ${DEPLOYMENT_URL}"

yarn install
export CYPRESS_BASE_URL="https://${DEPLOYMENT_URL}"
npx cypress run $4

# if configured, move test reports to the workspace folder. This way, they will
# be available for subsequent actions or jobs in the workflow.
# https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action#accessing-files-created-by-a-container-action
if [ -n "$5" ]; then
    echo "=> moving ${5} to /github/workspace"
    echo "=> contents of ${5}:"
    ls -la ${5}
    mv ${5} /github/workspace
    echo "=> contents of /github/workspace:"
    ls -la /github/workspace
    echo "=> contents of /github/workspace/${5}:"
    ls -la /github/workspace/${5}
fi

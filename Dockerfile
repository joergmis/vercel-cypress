# https://hub.docker.com/r/cypress/included/tags
FROM cypress/included:13.6.0

# Add the Google Chrome public key
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | tee /etc/apt/trusted.gpg.d/google.asc >/dev/null

# Install jq
RUN apt-get update && apt-get install -y jq

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
#!/bin/bash

# Make sure the stop and start scripts are executable
chmod +x stop_containers.sh

# Run the stop script
./stop_containers.sh

# Check if the stop script executed successfully
if [ $? -ne 0 ]; then
  echo "Failed to stop and remove containers. Exiting."
  exit 1
fi

# Remove the volume to clear the database data
docker volume rm safehouse_postgres_volume || true

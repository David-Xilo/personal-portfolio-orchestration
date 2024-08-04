#!/bin/bash

# Make sure the stop and start scripts are executable
chmod +x stop_containers.sh
chmod +x start_containers.sh

# Run the stop script
./stop_containers.sh

# Check if the stop script executed successfully
if [ $? -ne 0 ]; then
  echo "Failed to stop and remove containers. Exiting."
  exit 1
fi

# Run the start script
./start_containers.sh

# Check if the start script executed successfully
if [ $? -ne 0 ]; then
  echo "Failed to build images and start containers. Exiting."
  exit 1
fi

echo "Containers restarted successfully."

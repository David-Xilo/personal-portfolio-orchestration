#!/bin/bash

# Stop containers
docker stop safehouse-main-front-container || true
docker stop safehouse-tech-back-container || true
docker stop safehouse-db-container || true

# Remove containers
docker rm safehouse-main-front-container || true
docker rm safehouse-tech-back-container || true
docker rm safehouse-db-container || true

# Remove the Docker network
docker network rm safehouse-db-network || true

echo "Network and containers have been removed successfully."


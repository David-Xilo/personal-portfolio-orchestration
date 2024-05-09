#!/bin/bash

# Create Docker network if it doesn't exist
docker network create safehouse-db-network || true

# Stop and remove containers if they are already running
docker stop safehouse-main-front-container || true
docker rm safehouse-main-front-container || true

docker stop safehouse-tech-back-container || true
docker rm safehouse-tech-back-container || true

docker stop safehouse-db-container || true
docker rm safehouse-db-container || true

# DB
docker build -t safehouse-db ../../safehouse-db-schema

# Backend
docker build -t safehouse-tech-back ../../safehouse-tech-back

# Frontend
docker build -t safehouse-main-front ../../safehouse-main-front


# Start DB container
docker run -d \
  --network safehouse-db-network \
  --name safehouse-db-container \
  -e POSTGRES_DB=safehouse-main-db \
  -e POSTGRES_USER=safehouse-main-user \
  -e POSTGRES_PASSWORD=mypassword \
  -p 5432:5432 \
  -v my_postgres_volume:/var/lib/postgresql/data \
  safehouse-db

# Start backend container
docker run --network safehouse-db-network --name safehouse-tech-back-container -p 4000:4000 -d safehouse-tech-back

# Start frontend container
docker run --name safehouse-main-front-container -p 3000:3000 -d safehouse-main-front

echo "All containers started successfully."


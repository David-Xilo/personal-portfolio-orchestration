#!/bin/bash

# Create Docker network if it doesn't exist
docker network create safehouse-db-network || true

# Stop and remove containers if they are already running
docker stop safehouse-main-front-container || true
docker rm safehouse-main-front-container || true

docker stop safehouse-main-back-container || true
docker rm safehouse-main-back-container || true

docker stop safehouse-db-container || true
docker rm safehouse-db-container || true

# DB
docker build -t safehouse-db ../../safehouse-db-schema

# Backend
docker build -t safehouse-main-back ../../safehouse-main-back

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
  -v safehouse_postgres_volume:/var/lib/postgresql/data \
  safehouse-db

echo "Waiting for PostgreSQL to be ready (timeout: 30s)..."
timeout=30
while ! docker exec safehouse-db-container pg_isready -U safehouse-main-user -d safehouse-main-db; do
  sleep 1
  timeout=$((timeout - 1))
  if [ $timeout -le 0 ]; then
    echo "Timeout reached. PostgreSQL is not ready."
    exit 1
  fi
done

# Start backend container
docker run -e ENV=development -e FRONTEND_URL=http://localhost:3000 --network safehouse-db-network --name safehouse-main-back-container -p 4000:4000 -d safehouse-main-back

# Start frontend container
docker run --name safehouse-main-front-container -p 3000:3000 -d safehouse-main-front

echo "All containers started successfully."


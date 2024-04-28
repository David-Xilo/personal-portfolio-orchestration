#!/bin/bash

# Build Containers

# DB

docker build -t safehouse-db /../../safehouse-db-schema

# Backend

docker build -t safehouse-back /../../safehouse-tech-back

# Frontend

docker build -t safehouse-front /../../safehouse-main-front


# Start DB container

docker run -d \
  --name safehouse-db-container \
  -e POSTGRES_DB=mydatabase \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  -p 5432:5432 \
  -v my_postgres_volume:/var/lib/postgresql/data \
  safehouse-db

# Start backend container

docker run --name safehouse-back-container -p 4000:4000 -d safehouse-back

# Start frontend container

docker run --name safehouse-front-container -p 3000:3000 -d safehouse-front

echo "All containers started successfully."
#!/bin/bash

# Stop Containers

# Frontend

docker stop safehouse-main-front-container

docker rm safehouse-main-front-container


# Backend

docker stop safehouse-tech-back-container

docker rm safehouse-tech-back-container


# DB container

docker stop safehouse-db-container

docker rm safehouse-db-container


echo "All containers stopped successfully."

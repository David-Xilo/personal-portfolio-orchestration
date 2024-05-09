@echo off
REM Stop Containers

REM Frontend
docker stop safehouse-main-front-container
docker rm safehouse-main-front-container

REM Backend
docker stop safehouse-tech-back-container
docker rm safehouse-tech-back-container

REM DB container
docker stop safehouse-db-container
docker rm safehouse-db-container

echo All containers stopped successfully.

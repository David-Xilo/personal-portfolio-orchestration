@echo off

REM Build Containers

REM DB

docker build -t safehouse-db /../../safehouse-db-schema

REM Backend

docker build -t safehouse-back /../../safehouse-tech-back

REM Frontend

docker build -t safehouse-front /../../safehouse-main-front


REM Start DB container

docker run -d \
  --name safehouse-db-container \
  -e POSTGRES_DB=mydatabase \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  -p 5432:5432 \
  -v my_postgres_volume:/var/lib/postgresql/data \
  safehouse-db

REM Start backend container

docker run --name safehouse-back-container -p 4000:4000 -d safehouse-back

REM Start frontend container

docker run --name safehouse-front-container -p 3000:3000 -d safehouse-front

echo All containers started successfully.
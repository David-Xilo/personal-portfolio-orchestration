
docker stop safehouse-main-back-container || true
docker rm safehouse-main-back-container || true

docker build -t safehouse-main-back ../../safehouse-main-back

# Start backend container
docker run --network safehouse-db-network --name safehouse-main-back-container -p 4000:4000 -d safehouse-main-back

echo "Backend Reloaded"


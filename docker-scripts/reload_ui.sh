
docker stop safehouse-main-front-container || true
docker rm safehouse-main-front-container || true

docker build -t safehouse-main-front ../../safehouse-main-front

docker run --name safehouse-main-front-container -p 3000:3000 -d safehouse-main-front

echo "UI Reloaded"


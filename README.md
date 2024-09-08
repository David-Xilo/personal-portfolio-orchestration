# safehouse-orchestration
safehouse orchestration


## see logs

docker logs safehouse-db-container -f

docker logs safehouse-tech-back-container -f

docker logs safehouse-main-front-container -f

## shell the container

docker exec -it safehouse-db-container /bin/bash

docker exec -it safehouse-tech-back-container /bin/sh

docker exec -it safehouse-main-front-container /bin/sh

# debugging DB

After shelling the container

psql -h <host> -U <user> -d <db_name>

to check tables:
\dt


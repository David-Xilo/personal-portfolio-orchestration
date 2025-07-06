# safehouse-orchestration
safehouse orchestration

# Setup commands

### 1. One-time setup (creates infrastructure)
./setup-workload-identity.sh

### 2. One-time setup (creates secrets)
./setup-secrets.sh

### 3. Bind each repository (run for each repo)
./bind-repository.sh safehouse-main-back
./bind-repository.sh safehouse-main-front  
./bind-repository.sh safehouse-db-schema
./bind-repository.sh safehouse-orchestration

### 4. Verify (optional, anytime)
./verify-setup.sh




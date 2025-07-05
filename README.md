# safehouse-orchestration
safehouse orchestration

# Setup commands

### 1. One-time setup (creates infrastructure)
./setup-workload-identity.sh

### 2. Bind each repository (run for each repo)
./bind-repository.sh safehouse-main-back
./bind-repository.sh safehouse-main-front  
./bind-repository.sh safehouse-db-schema
./bind-repository.sh safehouse-orchestration

### 3. Verify (optional, anytime)
./verify-setup.sh




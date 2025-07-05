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


1. Replace hardcoded credentials with environment variables or secrets management
2. Enable database backups for production
3. Extend audit log retention to 90+ days
4. Use parameter references instead of hardcoded values
5. Enable SSL/TLS for all database connections
6. Configure security monitoring alerts
7. Pin Terraform provider versions
8. Implement proper secret rotation
9. Add resource limits to all containers
10. Use least-privilege IAM permissions





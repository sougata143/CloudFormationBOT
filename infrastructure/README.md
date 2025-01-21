# Make script executable
chmod +x infrastructure/scripts/clideployment.sh

# Deploy all stacks
./infrastructure/scripts/clideployment.sh deploy

# Rollback all stacks
./infrastructure/scripts/clideployment.sh rollback
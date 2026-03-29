#!/bin/bash
DESTINATION=$1
PORT=$2
CHAT=$3
ENVIRONMENT=$4  # New parameter to specify prod or test

# Clone Odoo directory
git clone --depth=1 https://github.com/Mugahedb/odoo-18-docker-compose $DESTINATION
rm -rf $DESTINATION/.git

# Create PostgreSQL directory
mkdir -p $DESTINATION/postgresql

# Change ownership to current user and set restrictive permissions for security
sudo chown -R $USER:$USER $DESTINATION
sudo chmod -R 700 $DESTINATION  # Only the user has access

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Running on macOS. Skipping inotify configuration."
else
  # System configuration
  if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
    echo $(grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf)
  else
    echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
  fi
  sudo sysctl -p
fi

# Set ports in docker-compose.yml
# Update docker-compose configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS sed syntax
  sed -i '' 's/10018/'$PORT'/g' $DESTINATION/docker-compose.yml
  sed -i '' 's/20018/'$CHAT'/g' $DESTINATION/docker-compose.yml
else
  # Linux sed syntax
  sed -i 's/10018/'$PORT'/g' $DESTINATION/docker-compose.yml
  sed -i 's/20018/'$CHAT'/g' $DESTINATION/docker-compose.yml
fi

# Modify service names dynamically based on the environment (prod or test)
if [[ "$ENVIRONMENT" == "prod" ]]; then
  # Replace db: to db-prod: and odoo17: to odoo17-prod:
  sed -i 's/^  db:$/  db-prod:/g' $DESTINATION/docker-compose.yml
  sed -i 's/^  odoo18:/  odoo18-prod:/g' $DESTINATION/docker-compose.yml

  # Modify the depends_on value to point to db-prod
  sed -i '/depends_on:/,/\]/s/\s*db\s*/  db-prod/g' $DESTINATION/docker-compose.yml

  # Update the HOST variable inside the odoo container to use db-prod
  sed -i 's/HOST=db/HOST=db-prod/g' $DESTINATION/docker-compose.yml

elif [[ "$ENVIRONMENT" == "test" ]]; then
  # Replace db: to db-test: and odoo18: to odoo18-test:
  sed -i 's/^  db:$/  db-test:/g' $DESTINATION/docker-compose.yml
  sed -i 's/^  odoo18:/  odoo18-test:/g' $DESTINATION/docker-compose.yml

  # Modify the depends_on value to point to db-test
  sed -i '/depends_on:/,/\]/s/\s*db\s*/  db-test/g' $DESTINATION/docker-compose.yml

  # Update the HOST variable inside the odoo container to use db-test
  sed -i 's/HOST=db/HOST=db-test/g' $DESTINATION/docker-compose.yml

else
  echo "Invalid environment. Please specify 'prod' or 'test'."
  exit 1
fi

# Ensure the networks section is not modified by the script
# We don't modify the networks section here

# Set file and directory permissions after installation
find $DESTINATION -type f -exec chmod 644 {} \;
find $DESTINATION -type d -exec chmod 755 {} \;

chmod +x $DESTINATION/entrypoint.sh

# Run Odoo
if ! is_present="$(type -p "docker-compose")" || [[ -z $is_present ]]; then
  docker compose -f $DESTINATION/docker-compose.yml up -d
else
  docker-compose -f $DESTINATION/docker-compose.yml up -d
fi

echo "Odoo started at http://localhost:$PORT | Master Password: minhng.info | Live chat port: $CHAT"

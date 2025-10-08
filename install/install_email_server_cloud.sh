#!/bin/bash

echo ''
echo 'Checking parameters...'

if [ -z "$smtp_host_domain" ]
then
    echo 'Set the first parameter is mandatory: smtp_host'
    exit 2
fi

if [ -z "$noreply_domain" ]; 
then
  noreply_domain=$smtp_host_domain
fi

SMTP_HOST=$smtp_host_domain
echo $SMTP_HOST
INFRASTRUCTURE_DOMAIN=`hostname`
echo "image=$image"
echo 'Parameters OK'

echo "Current location:" `pwd`
mkdir -p email-server
cd email-server
echo "Current location:" `pwd`

echo 'Getting the Tools for installing email-server...'
DMS_GITHUB_URL='https://raw.githubusercontent.com/priyankasaini0520/sainipriyanka/master'
sudo curl -o setup.sh $DMS_GITHUB_URL/setup.sh;
sudo chmod a+x ./setup.sh
sudo curl -o docker-compose.yml $DMS_GITHUB_URL/compose.yaml
line="`grep docker-mailserver:latest docker-compose.yml`"
sed -i "s+$line+    image: $image+g" docker-compose.yml
sudo curl -o mailserver.env $DMS_GITHUB_URL/mailserver.env

#sed -i 's/25:/8082:/' docker-compose.yml
sudo chmod +x setup.sh
echo ''
echo 'Updating the environment variables as needed by the current deployment...'
echo ''

echo 'HOSTNAME=127.0.0.1'
sudo sed -i 's+hostname: mail+hostname: '"$INFRASTRUCTURE_DOMAIN"'+g' docker-compose.yml

echo 'DOMAINNAME='"$SMTP_HOST"
sudo sed -i 's+domainname: example.com+domainname: '"$SMTP_HOST"'+g' docker-compose.yml

if [ -z "$RELAY_DOMAINS" ]; then
  RELAY_DOMAINS="$SMTP_HOST"
fi

sudo sed -i 's+RELAY_DOMAINS=+RELAY_DOMAINS='"$RELAY_DOMAINS"'+g' mailserver.env

echo 'Update OK'
echo ''

echo ''
echo 'Configuring accounts and launching the e-mail server...'
echo ''

sudo pkill -f smtp-sink
#sudo systemctl stop postfix
sudo docker-compose up -d mailserver

sudo sed -i 's+-ti+-i+g' setup.sh

sudo ./setup.sh email add testqa@"$SMTP_HOST" changeme
sudo ./setup.sh email add no-reply@"$SMTP_HOST" changeme
sudo ./setup.sh email add bounce-acc-intg1@"$SMTP_HOST" changeme
sudo ./setup.sh email add bounce.@"$SMTP_HOST" changeme
sudo ./setup.sh config dkim
sudo mount /tmp -o remount,exec
sudo docker-compose down
sudo docker-compose up -d mailserver
sleep 30
CONTAINER_NAME=$(sudo docker-compose ps -q mailserver)
# Update mybounce.py
echo "Updating mybounce.py..."
sudo docker exec -i $CONTAINER_NAME sed -i "s/mailfrom = .*/mailfrom = 'testqa@$SMTP_HOST'/" /etc/postfix/mybounce.py

# Fix Postfix permissions inside container
echo "Fixing Postfix permissions..."
sudo docker exec -i $CONTAINER_NAME chmod -R 755 /var/spool/postfix
sudo docker exec -i $CONTAINER_NAME chown -R postfix:postfix /var/spool/postfix

# Reload Postfix to apply changes
echo "Reloading Postfix..."
sudo docker exec -i $CONTAINER_NAME postfix reload

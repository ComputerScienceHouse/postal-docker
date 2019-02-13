#!/bin/bash
set -e

SIGNING_KEY_PATH=${SIGNING_KEY_PATH:-"/opt/postal/config/signing.key"}
LETS_ENCRYPT_KEY_PATH=${LETS_ENCRYPT_KEY_PATH:-"/opt/postal/config/lets_encrypt.pem"}

if [ -z "$LETS_ENCRYPT_EMAIL" ]; then
    echo "ERROR: You must specify a contact email address for Let's Encrypt by setting the LETS_ENCRYPT_EMAIL environment variable."
    exit 1
fi

echo "Welcome to Postal!"

# Generate config
p2 -t /tmp/postal.yml.j2 -o /opt/postal/config/postal.yml

if [ ! -f $SIGNING_KEY_PATH ]; then
    # Generate signing key
    echo "==> Generating Postal signing key - this should be made persistent!"
    openssl genrsa -out $SIGNING_KEY_PATH 1024
fi

if [ ! -f $LETS_ENCRYPT_KEY_PATH ]; then
    # Generate Let's Encrypt private key
    echo "==> Generating Let's Encrypt private key - this should be made persistent!"
    openssl genrsa -out $LETS_ENCRYPT_KEY_PATH 2048

    # Register account with Let's Encrypt
    /opt/postal/bin/postal register-lets-encrypt "$LETS_ENCRYPT_EMAIL"
fi

if [ -z "$MYSQL_HOSTNAME" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_DATABASE" ]; then
    echo "ERROR: One or more MySQL environment variables were not defined. Please check your configuration."
    exit 1
fi

pushd /opt/postal >/dev/null

DB_TABLES=`mysql \
    --host="$MYSQL_HOSTNAME" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD" \
    --database="$MYSQL_DATABASE" \
    --execute="show tables;"`

if [ -z "$DB_TABLES" ]; then
    # Database is empty
    echo "==> Initializing database..."
    HOME="/tmp" bundle exec rake db:schema:load db:seed
else
    echo "==> Migrating database..."
    HOME="/tmp" bundle exec rake db:migrate
fi

popd >/dev/null

# Clean Up
rm -rf /opt/postal/tmp/pids/*
rm -rf /tmp/.bundle

echo "==> Postal reconfigured!"

# Start Postal
/opt/postal/bin/postal "${@:-run}"

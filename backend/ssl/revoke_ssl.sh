#!/bin/bash

echo "Revoking certificate at /etc/letsencrypt/live/${1}/"
certbot revoke --cert-path /etc/letsencrypt/live/$1/fullchain.pem -n


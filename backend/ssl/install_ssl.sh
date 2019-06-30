#!/bin/bash

apt-get update -y
apt-get install software-properties-common -y
add-apt-repository universe -y
add-apt-repository ppa:certbot/certbot -y
apt-get update -y

apt-get install certbot -y

certbot certonly --standalone -d $1 -n --agree-tos -m $2



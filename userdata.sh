#!/bin/bash

sudo apt-get update
sudo apt install apache2 -y
sudo systemctl start apache2
sudo git clone https://github.com/amolshete/card-website.git
sudo cp -rf /card-website/* /var/www/html/


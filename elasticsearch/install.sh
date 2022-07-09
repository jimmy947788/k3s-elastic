#!/bin/bash

apt-get update -y
apt-get install openjdk-8-jdk -y
apt-get install nginx

# add elasticsearch key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

apt-get install apt-transport-https

# 注意版本
# deb https://artifacts.elastic.co/packages/6.x/apt stable main"
# deb https://artifacts.elastic.co/packages/7.x/apt stable main"
# deb https://artifacts.elastic.co/packages/8.x/apt stable main"
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee –a /etc/apt/sources.list.d/elastic-7.x.list
apt-get update -y
apt-get install elasticsearch=7.10.1 -y

mv $(pwd)/elasticsearch/elasticsearch.yml  /etc/elasticsearch/elasticsearch.yml
mv $(pwd)/elasticsearch/jvm.options        /etc/elasticsearch/jvm.options

SERVICE="elasticsearch.service"
systemctl is-active --quiet $SERVICE && echo "Service is running" || systemctl start $SERVICE
systemctl is-enabled --quiet $SERVICE && echo "Service is enabled" || systemctl enable $SERVICE


apt-get install kibana=7.10.1 -y
mv $(pwd)/elasticsearch/kibana.yml  /etc/kibana/kibana.yml
SERVICE="kibana.service"
systemctl is-active --quiet $SERVICE && echo "Service is running" || systemctl start $SERVICE
systemctl is-enabled --quiet $SERVICE && echo "Service is enabled" || systemctl enable $SERVICE
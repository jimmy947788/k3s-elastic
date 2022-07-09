#!/bin/bash

scp elasticsearch-single-node.yml jimmywu@192.168.0.195:~/elasticsearch/elasticsearch.yml
scp install.sh jimmywu@192.168.0.195:~/elasticsearch/
scp jvm.options jimmywu@192.168.0.195:~/elasticsearch/
scp kibana.yml jimmywu@192.168.0.195:~/elasticsearch/
ssh jimmywu@192.168.0.195 "echo '29168701'| sudo -S bash ~/elasticsearch/install.sh"
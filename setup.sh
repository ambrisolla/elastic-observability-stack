#!/bin/bash 
set -eo pipefail
tabs -4
clear


startup() {
	echo -ne "Starting \"Elastic Observability Stack for Development\"\n\n"
	if ! test -e /usr/bin/docker
	then
		echo "Error: Please install Docker first!"
		exit 1 
	fi
}

start_elasticsearch() {
	docker compose up elasticsearch -d > /dev/null  2> /dev/null
	while [ ! $(curl -I 'localhost:9200/' 2> /dev/null > /dev/null && echo $? ) ]
	do
		echo -ne "  - Starting Elasticsearch...\r"
		sleep 1
	done
	echo "  - Starting Elasticsearch... Done"
}

start_kibana() {
	export ELASTICSEARCH_PASSWORD=$(\
		docker exec -it elasticsearch \
		/usr/share/elasticsearch/bin/elasticsearch-reset-password \
		-u kibana_system -b \
		| grep "New value" \
		| awk '{print $NF}' \
		| sed "s/\r//g")
	docker compose  up kibana -d > /dev/null  2> /dev/null
	while [ ! $(curl -I 'localhost:5601/' 2> /dev/null > /dev/null && echo $? ) ]
    do
        echo -ne "  - Starting Kibana...\r"
        sleep 1
    done
	curl -u elastic:password -X POST \
		"http://localhost:5601/api/fleet/epm/packages/apm/8.0.0" \
		-H 'kbn-xsrf: true' 2> /dev/null > /dev/null
	if test $? -ne 0; then
		echo "Error: Failed to install APM integration!"
		exit 1
	fi
	echo "  - Starting Kibana... Done"
}

start_apm() {
	echo -ne "  - Starting APM Server...\r"
	source .env
	cat apm-server.yml.example |\
	sed  "s|__ELASTICSEARCH_PASSWORD__|$ELASTICSEARCH_PASSWORD|g" \
	> apm-server.yml
	docker compose  up apm -d > /dev/null  2> /dev/null
	if test $? -ne 0; then
		echo "Error: Failed to start APM Server!"
		exit 1
	fi
	echo -ne "  - Starting APM Server... Done"
}

success_message() {
	echo -ne "\n\n\tElastic Observability Stack was deployed successfully! "
	echo -ne "To access Kibana, open the following address in your browser: http://0.0.0.0.5601"
	echo -ne "\n\n\tCredentials: elastic/${ELASTICSEARCH_PASSWORD}"
}

startup
start_elasticsearch
start_kibana
start_apm
success_message
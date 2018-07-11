#!/bin/bash
# Setup Nexus Project
set -x
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry


# Ideally just calls a template
oc project ${GUID}-nexus
oc new-app -f ./Infrastructure/templates/nexus_template.yaml --param VOLUME_CAPACITY=2Gi NEXUS_VERSION=3.6.0 SERVICE_NAME=$GUID-nexus -n ${GUID}-nexus

while : ; do
    echo "Checking if Nexus is Ready..."
    oc get pod -n ${GUID}-nexus|grep -v deploy|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
    sleep 10
done

curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')
rm setup_nexus3.sh

oc expose dc nexus3 --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000

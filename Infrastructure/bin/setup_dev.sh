#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"
oc project ${GUID}-parks-dev

#Allow application permission to discover available routes
oc policy add-role-to-user view --serviceaccount=default


##Deploy mongo 
MEMORY_LIMIT="512Mi"
NAMESPACE="openshift"
DATABASE_SERVICE_NAME="mongodb"
MONGODB_USER="mongodb"
MONGODB_PASSWORD="mongodb"
MONGODB_DATABASE="parks"
MONGODB_ADMIN_PASSWORD="mongodb"
VOLUME_CAPACITY="1Gi"
MONGODB_VERSION="3.2" #could be latest

oc new-app -f ../templates/mongodb_persistent.json --param MEMORY_LIMIT=$MEMORY_LIMIT \
--param NAMESPACE=${NAMESPACE} \
--param DATABASE_SERVICE_NAME=${DATABASE_SERVICE_NAME} \
--param MONGODB_USER=${MONGODB_USER} \
--param MONGODB_PASSWORD=${MONGODB_PASSWORD} \
--param MONGODB_DATABASE=${MONGODB_DATABASE} \
--param MONGODB_ADMIN_PASSWORD=${MONGODB_ADMIN_PASSWORD} \
--param VOLUME_CAPACITY=${VOLUME_CAPACITY} \
--param MONGODB_VERSION=${MONGODB_VERSION} 


#Create build for parks-map 
oc new-build --binary=true --name=parksmap --image-stream=redhat-openjdk18-openshift:1.2 --allow-missing-imagestream-tags=true
oc new-app ${GUID}-parks-dev/parksmap:0.0-0 --name=parksmap --allow-missing-imagestream-tags=true -l type=parksmap-frontend -e APPNAME="ParksMap (Dev)"
oc rollout pause dc parksmap
oc set triggers dc/parksmap --remove-all
#Expose front end to outside world
oc expose svc/parksmap --port=8080
#Add Liveliness and readiness probes
oc set probe dc/parksmap --readiness --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30
oc set probe dc/parksmap --liveness --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30
oc rollout resume dc parksmap


#Build National Parks
oc new-build --binary=true --name=nationalparks --image-stream=redhat-openjdk18-openshift:1.2
oc new-app ${GUID}-parks-dev/nationalparks:0.0-0 --name=nationalparks --allow-missing-imagestream-tags=true -l type=parksmap-backend -e APPNAME="National Parks (Dev)" \
-e DB_HOST=$DATABASE_SERVICE_NAME \
-e DB_PORT=27017 \
-e DB_USERNAME=$MONGODB_USER \
-e DB_PASSWORD=$MONGODB_PASSWORD \
-e DB_NAME=$MONGODB_DATABASE

oc rollout pause dc nationalparks
#Add Liveliness and readiness probes
oc set probe dc/nationalparks --readiness --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30
oc set probe dc/nationalparks --liveness --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30
#Add post deployment hook!
oc patch dc/nationalparks --patch '{"spec":{"strategy":{"rollingParams":{"post":{"failurePolicy": "retry","execNewPod":{"containerName":"nationalparks","command":["/bin/sh","-c","curl http://${SERVICE_NAME}:8080/ws/data/load/"], "env": [{"name": "SERVICE_NAME", "value":"nationalparks"}]}}}}}}'
oc rollout resume dc nationalparks


#Build MLB Parks
oc new-build --binary=true --name=mlbparks --image-stream=jboss-eap70-openshift:1.7
oc new-app ${GUID}-parks-dev/mlbparks:0.0-0 --name=mlbparks --allow-missing-imagestream-tags=true -l type=parksmap-backend -e APPNAME="MLB Parks (Dev)" \
-e DB_HOST=$DATABASE_SERVICE_NAME \
-e DB_PORT=27017 \
-e DB_USERNAME=$MONGODB_USER \
-e DB_PASSWORD=$MONGODB_PASSWORD \
-e DB_NAME=$MONGODB_DATABASE

oc rollout pause dc mlbparks
#Add Liveliness and readiness probes
oc set probe dc/mlbparks --readiness --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30
oc set probe dc/mlbparks --liveness --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30
#Add post deployment hook!
oc patch dc/mlbparks --patch '{"spec":{"strategy":{"rollingParams":{"post":{"failurePolicy": "retry","execNewPod":{"containerName":"mlbparks","command":["/bin/sh","-c","curl http://${SERVICE_NAME}:8080/ws/data/load/"], "env": [{"name": "SERVICE_NAME", "value":"mlbparks"}]}}}}}}'
oc rollout resume dc mlbparks

echo "Finished Setup..."

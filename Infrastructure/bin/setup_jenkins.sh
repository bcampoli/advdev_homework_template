#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"
oc project ${GUID}-jenkins
# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student

oc new-app -f ../templates/jenkins_template.yaml --param VOLUME_CAPACITY=4gi JENKINS_VERSION=latest SERVICE_NAME=${GUID}-jenkins

oc create -f ../templates/dev-pipeline.yaml
oc set env buildconfigs/dev-pipeline GUID="$GUID"


pushd ../docker-files/skopeo
docker build . -t jenkins-slave-appdev:v3.9
popd

docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock --name skopeo_bash jenkins-slave-appdev:v3.9 bash

docker exec -it skopeo_bash \
  skopeo copy --dest-tls-verify=false --dest-creds=$(oc whoami):$(oc whoami -t) \
    docker-daemon:jenkins-slave-appdev:v3.9 \
    "docker://docker-registry-default.apps.na39.openshift.opentlc.com/${GUID}-jenkins/jenkins-slave-appdev:latest"

docker rm -f skopeo_bash


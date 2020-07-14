#!/bin/bash

#
# You will need to ensure the following variables have correct values
#

export GITHUB_TOKEN="YOUR TOKEN"
export AWS_ACCESS_KEY_ID="YOUR KEY"
export AWS_SECRET_ACCESS_KEY="YOUR SECRET ACCESS KEY"

GIT_REPO=msgbus-core
BUCKET_NAME=msgbus-green
GITREF_OVERRIDE=release/2020.2.0
ENVIRONMENT=validation

rm -rf $GIT_REPO
git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/mdsol/${GIT_REPO}
cd $GIT_REPO
git checkout $GITREF_OVERRIDE
cd deploy/ansible

echo -e "\nStage IAM role\n"
ansible-playbook deploy_msgbus-iamrole.yaml --extra-vars "bucketName=$BUCKET_NAME envName=$ENVIRONMENT"

echo -e "\nStage S3\n"
ansible-playbook deploy_msgbus-s3.yaml --extra-vars "bucketName=$BUCKET_NAME envName=$ENVIRONMENT"

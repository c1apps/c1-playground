#!/bin/bash

#######################################
# Main:
# Deploys Jenkins on EKS Cluster
#######################################

function create_namespace() {
  # create namespace
  printf '%s' "Create jenkins namespace"
  kubectl create namespace jenkins
  printf '%s\n' " 🍼"
}

function whitelist_namespaces() {
  # whitelist some namespace for container security
  kubectl label namespace jenkins --overwrite ignoreAdmissionControl=true
}

function create_ecr_repository() {
  # Exports
  export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  export AWS_REGION=$(aws configure get region)
  export AWS_ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

  # Create ECR repository
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ECR
  if [[ $(aws ecr describe-repositories) =~ :repository/c1-jenkins ]]; then
    echo "c1-jenkins repository already exists"
  else
  aws ecr create-repository \
    --repository-name c1-jenkins \
    --image-scanning-configuration scanOnPush=true \
    --region $AWS_REGION
  fi
}

function create_jenkins_image() {
  printf '%s\n' "Create jenkins image"
  docker build -t $AWS_ECR/c1-jenkins:latest - < ${PGPATH}/templates/jenkins-dockerfile
  printf '%s\n' "Jenkins image created 🍻"
  docker push $AWS_ECR/c1-jenkins:latest
  printf '%s\n' "Jenkins image pushed to ECR 🍻"
}

function deploy_jenkins() {
  printf '%s\n' "Create jenkins image"
  docker build -t $AWS_ECR/c1-jenkins:latest - < ${PGPATH}/templates/jenkins-dockerfile
  printf '%s\n' "Jenkins image created 🍻"
  docker push $AWS_ECR/c1-jenkins:latest
  printf '%s\n' "Jenkins image pushed to ECR 🍻"
}

function main() {
  create_namespace
  whitelist_namespaces
  create_ecr_repository
  create_jenkins_image
  deploy_jenkins
}


# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
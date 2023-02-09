#!/bin/bash

# Exports

function clean_ecr_repository() {
  export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  export AWS_REGION=$(aws configure get region)
  export AWS_ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
  if [[ $(aws ecr describe-repositories) =~ :repository/c1-jenkins ]]; then
    aws ecr batch-delete-image --region $AWS_REGION \
    --image-ids "$(aws ecr list-images --region $AWS_REGION --repository-name c1-jenkins --query 'imageIds[*]' --output json)" || true
  else
    echo "c1-jenkins repository already deleted"
  fi
}

function delete_ecr_repository() {
  export AWS_REGION=$(aws configure get region)
  if [[ $(aws ecr describe-repositories) =~ :repository/c1-jenkins ]]; then
    aws ecr delete-repository \
    --repository-name c1-jenkins \
    --region $AWS_REGION
  else
    echo "c1-jenkins repository already deleted"
  fi
}

kubectl delete service c1-jenkins -n jenkins
kubectl delete deploy c1-jenkins -n jenkins
kubectl delete pvc jenkins-pvc -n jenkins
kubectl delete namespace jenkins
clean_ecr_repository
delete_ecr_repository

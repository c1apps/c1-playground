#!/bin/bash

function clean_ecr_repository() {
  export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  export AWS_REGION=$(aws configure get region)
  export AWS_ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
  if [[ $(aws ecr describe-repositories) =~ :repository/c1-jenkins ]]; then
    aws ecr batch-delete-image --region $AWS_REGION --repository-name c1-jenkins\
    --image-ids "$(aws ecr list-images --region $AWS_REGION --repository-name c1-jenkins --query 'imageIds[*]' --output json)" || true
  else
    echo "no images to delete in repo"
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

function delete_jenkins_dns_record() {
  export DOMAIN_NAME=c1demo.es
  export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name | jq '.HostedZones[] | select(.Name == "'$DOMAIN_NAME'.") | .Id' | grep -oP '(?<=")(.*?)(?=")')
  export JENKINS_ELB_URL=$(kubectl -n jenkins get svc c1-jenkins -o json | jq -r .status.loadBalancer.ingress[].hostname)
  
  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://<(cat << EOF
  {
  "Comment": "Create DNS record for Jenkins",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "jenkins.$DOMAIN_NAME",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$JENKINS_ELB_URL"
          }
        ]
      }
    }
  ]
}
EOF
)
}

delete_jenkins_dns_record
kubectl delete service c1-jenkins -n jenkins
kubectl delete deploy c1-jenkins -n jenkins
kubectl delete pvc jenkins-pvc -n jenkins
kubectl delete namespace jenkins
clean_ecr_repository
delete_ecr_repository
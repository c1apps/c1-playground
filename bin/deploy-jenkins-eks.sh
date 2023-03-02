#!/bin/bash

#######################################
# Main:
# Deploys Jenkins on EKS Cluster
#######################################

# Global Exports
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export AWS_REGION=$(aws configure get region)
export AWS_ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

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
  printf '%s\n' "Create Jenkins Volume"
  kubectl apply -f $PGPATH/templates/jenkins-eks-volume-claim.yaml -o yaml
  printf '%s\n' "Deploy Jenkins on EKS"
  AWS_ECR=${AWS_ECR} \
    envsubst <$PGPATH/templates/jenkins-eks-deployment.yaml | kubectl apply -f - -o yaml
  printf '%s\n' "Jenkins deployed on EKS 🍻"
}

function get_initial_admin_password() {
  export JENKINS_CONTAINER_NAME=$(kubectl get pods -n jenkins -o name)
  printf '%s' "Waiting for admin password"
  for i in {1..60} ; do
    sleep 2
    ADMIN_PASSWORD=$(kubectl exec -n jenkins ${JENKINS_CONTAINER_NAME} cat /var/jenkins_home/secrets/initialAdminPassword)
    if [ "${ADMIN_PASSWORD}" != "" ] ; then
      break
    fi
    printf '%s' "."
  done
  printf '\n'
}

function create_jenkins_dns_record() {
  export DOMAIN_NAME=c1demo.es
  export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name | jq '.HostedZones[] | select(.Name == "'$DOMAIN_NAME'.") | .Id' | grep -oP '(?<=")(.*?)(?=")')
  export JENKINS_ELB_URL=$(kubectl -n jenkins get svc c1-jenkins -o json | jq -r .status.loadBalancer.ingress[].hostname)
  
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://<(cat << EOF
  {
  "Comment": "Create DNS record for Jenkins",
  "Changes": [
    {
      "Action": "UPSERT",
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

function main() {
  create_namespace
  whitelist_namespaces
  create_ecr_repository
  create_jenkins_image
  deploy_jenkins
  get_initial_admin_password
  create_jenkins_dns_record

  #Access data
  export JENKINS_URL=$(kubectl -n jenkins get svc c1-jenkins -o json | jq -r .status.loadBalancer.ingress[].hostname)
  echo "Jenkins: http://${JENKINS_URL}" | tee -a ${PGPATH}/services
  echo "  U/P: admin / ${ADMIN_PASSWORD}" | tee -a ${PGPATH}/services
  echo | tee -a ${PGPATH}/services
}

# run main of no arguments given
if [[ $# -eq 0 ]] ; then
  main
fi
#!/bin/bash

# Get current region
# Overwrite with REGION=something sentry-get-reports.sh
REGION=${REGION:-$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')}
echo Using region ${REGION}

# Get the regions Sentry bucket
BUCKET=$(
    for bucket in $(aws s3api list-buckets --output json |  jq -r '.Buckets[] | select(.Name | contains("sentrystackset")) | .Name') ; do
        bucketregion=$(aws s3api get-bucket-location --bucket $bucket | jq -r .LocationConstraint)
        if [ "$bucketregion" == "$REGION" ] ; then
            echo $bucket
        fi
    done)
echo Using bucket ${BUCKET}

# Shift back in time
DATE=$(date --date '-1 day' +%Y-%m-%dT%H:%M:%S)
OUTDIR=sentry-reports-$(date --date '-1 day' +%Y-%m-%d_%H-%M-%S)

# Ensure reports directory
mkdir -p ${OUTDIR}

# Get, identify and file reports in subdirectories
for report in $(aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[?LastModified>=`'"$DATE"'`]' | jq -r '.[] | select(.Key | test("^scan-report.*final_report.json")) | .Key') ; do

    # Get and identify report
    scanid=$(echo $report | cut -d '/' -f 2)
    mkdir -p ${OUTDIR}/${scanid}
    aws s3 cp s3://${BUCKET}/$report ${OUTDIR}/${scanid}/final_report.json
    resourcetype=$(jq -r .resourceType ${OUTDIR}/${scanid}/final_report.json)

    mkdir -p ${OUTDIR}/${resourcetype}s

    # EBS
    if [ "$resourcetype" == "aws-ebs-volume" ] ; then
        instanceid=$(jq -r .metadata.AttachedInstances[0].InstanceID ${OUTDIR}/${scanid}/final_report.json)
        cat ${OUTDIR}/${scanid}/final_report.json | jq . > ${OUTDIR}/${resourcetype}s/${instanceid}.json
        rm -rf ${OUTDIR}/${scanid}
    fi

    # Lambda
    if [ "$resourcetype" == "aws-lambda-function" ] ; then
        functionname=$(jq -r .metadata.FunctionName ${OUTDIR}/${scanid}/final_report.json)
        cat ${OUTDIR}/${scanid}/final_report.json | jq . > ${OUTDIR}/${resourcetype}s/${functionname}.json
        rm -rf ${OUTDIR}/${scanid}
    fi

    # ECR
    if [ "$resourcetype" == "aws-ecr-image" ] ; then
        imageuri=$(jq -r .metadata.ImageURI ${OUTDIR}/${scanid}/final_report.json)
        cat ${OUTDIR}/${scanid}/final_report.json | jq . > ${OUTDIR}/${resourcetype}s/${imageuri//\//_}.json
        rm -rf ${OUTDIR}/${scanid}     
    fi
done

# DATE=$(date +%Y-%m-%d)
# DATE=$(date --date '-1 hour' +%Y-%m-%dT%H:%M:%S)
#aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[?LastModified>=`'"$DATE"'`]' | \
#  jq -r '.[] | select(.Key | startswith("scan-report") | endswith("final_report.json")) | .Key'

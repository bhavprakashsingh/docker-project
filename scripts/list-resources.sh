#!/bin/bash

# ============================================================================
# GLOBAL AWS RESOURCE INVENTORY SCRIPT (MARKDOWN GENERATOR)
# ============================================================================
# This script scans ALL active regions and generates AWS_RESOURCE_REPORT.md
# ============================================================================

REPORT_FILE="AWS_RESOURCE_REPORT.md"

echo "# 📋 AWS Resource Inventory Report" > $REPORT_FILE
echo "Generated on: $(date)" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Get only enabled regions (to avoid AuthFailure on opt-in regions)
echo "🌎 Fetching active regions..."
REGIONS=$(aws ec2 describe-regions --query "Regions[?OptInStatus!='not-opted-in'].RegionName" --output text)

for REGION in $REGIONS; do
    echo "🔍 Scanning $REGION..."
    
    # Check for resources first to avoid empty sections
    INSTANCES=$(aws ec2 describe-instances --region $REGION --query "Reservations[].Instances[].InstanceId" --output text)
    VPCS=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text)
    VOLUMES=$(aws ec2 describe-volumes --region $REGION --query "Volumes[].VolumeId" --output text)

    if [ ! -z "$INSTANCES" ] || [ ! -z "$VPCS" ] || [ ! -z "$VOLUMES" ]; then
        echo "## 📍 Region: $REGION" >> $REPORT_FILE
        echo "" >> $REPORT_FILE

        if [ ! -z "$INSTANCES" ]; then
            echo "### 🖥️ EC2 Instances" >> $REPORT_FILE
            echo "| Name | Instance ID | Type | State | Public IP |" >> $REPORT_FILE
            echo "| --- | --- | --- | --- | --- |" >> $REPORT_FILE
            aws ec2 describe-instances --region $REGION \
                --query "Reservations[].Instances[].[(Tags[?Key=='Name']|[0].Value || 'None'), InstanceId, InstanceType, State.Name, (PublicIpAddress || 'None')]" \
                --output text | sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/' >> $REPORT_FILE
            echo "" >> $REPORT_FILE
        fi

        if [ ! -z "$VPCS" ]; then
            echo "### 🌐 Custom VPCs" >> $REPORT_FILE
            echo "| Name | VPC ID | CIDR | Default |" >> $REPORT_FILE
            echo "| --- | --- | --- | --- |" >> $REPORT_FILE
            aws ec2 describe-vpcs --region $REGION \
                --query "Vpcs[].[(Tags[?Key=='Name']|[0].Value || 'None'), VpcId, CidrBlock, to_string(IsDefault)]" \
                --output text | sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/' >> $REPORT_FILE
            echo "" >> $REPORT_FILE
        fi

        if [ ! -z "$VOLUMES" ]; then
            echo "### 💾 EBS Volumes" >> $REPORT_FILE
            echo "| Volume ID | Size (GB) | Type | State | Attached Instance |" >> $REPORT_FILE
            echo "| --- | --- | --- | --- | --- |" >> $REPORT_FILE
            aws ec2 describe-volumes --region $REGION \
                --query "Volumes[].[VolumeId, to_string(Size), VolumeType, State, (Attachments[0].InstanceId || 'None')]" \
                --output text | sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/' >> $REPORT_FILE
            echo "" >> $REPORT_FILE
        fi
        
        echo "---" >> $REPORT_FILE
    fi
done

echo "## 🪣 Global: S3 Buckets" >> $REPORT_FILE
echo "| Bucket Name | Creation Date |" >> $REPORT_FILE
echo "| --- | --- |" >> $REPORT_FILE
aws s3api list-buckets --query "Buckets[].[Name, CreationDate]" --output text | sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/' >> $REPORT_FILE

echo "" >> $REPORT_FILE
echo "✅ Report generated: $REPORT_FILE"
echo "========================================================================"

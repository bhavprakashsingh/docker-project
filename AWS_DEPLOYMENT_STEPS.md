# 🚀 AWS Infrastructure & Deployment Steps (us-east-1)

This guide provides the exact commands to set up your AWS infrastructure and deploy the Docker project.

## 🛠️ Part 1: Infrastructure Setup (AWS CLI)

Run these commands in your terminal (**Bash/WSL syntax**). Ensure you have AWS CLI configured.

### 1. Networking (VPC & Subnet)
```bash
# 1. Create VPC (10.0.0.0/16)
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text --region us-east-1)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=real-estate-vpc --region us-east-1

# 2. Create Public Subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' --output text --region us-east-1)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region us-east-1

# 3. Create & Attach Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region us-east-1)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region us-east-1

# 4. Create Route Table & Add Route to Internet
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region us-east-1)
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region us-east-1
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region us-east-1
```

### 2. Security & Access
```bash
# 5. Create Security Group
SG_ID=$(aws ec2 create-security-group --group-name "real-estate-sg" --description "Security group for Real Estate app" --vpc-id $VPC_ID --query 'GroupId' --output text --region us-east-1)

# 6. Open Ports (22, 80, 443)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region us-east-1
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-east-1
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region us-east-1

# 7. Create Key Pair
aws ec2 create-key-pair --key-name "real-estate-key" --query 'KeyMaterial' --output text > real-estate-key.pem
chmod 400 real-estate-key.pem
```

### 3. EBS Volumes & EC2 Launch
```bash
# 8. Create EBS Volumes (30GB for Postgres, 5GB for SSL)
VOL_DB=$(aws ec2 create-volume --availability-zone us-east-1a --size 30 --volume-type gp3 --query 'VolumeId' --output text --region us-east-1)
VOL_SSL=$(aws ec2 create-volume --availability-zone us-east-1a --size 5 --volume-type gp3 --query 'VolumeId' --output text --region us-east-1)

# 9. Launch t3.micro EC2 Instance (Free Tier Eligible)
INSTANCE_ID=$(aws ec2 run-instances --image-id ami-009d9173b44d0482b --count 1 --instance-type t3.micro --key-name real-estate-key --security-group-ids $SG_ID --subnet-id $SUBNET_ID --query 'Instances[0].InstanceId' --output text --region us-east-1)

# 10. Wait and Attach Volumes (Using safer device names)
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region us-east-1
aws ec2 attach-volume --volume-id $VOL_DB --instance-id $INSTANCE_ID --device /dev/sdf --region us-east-1
aws ec2 attach-volume --volume-id $VOL_SSL --instance-id $INSTANCE_ID --device /dev/sdg --region us-east-1

# 11. Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region us-east-1)
echo "Public IP: $PUBLIC_IP"
```


---

## 🚢 Part 2: Deployment (On EC2)

Once the instance is running, follow these steps to deploy your Docker images.

### 1. Transfer Files to EC2
Run these from your **local machine** (in the `docker-project` directory):
```bash
# Set variables
IP="$PUBLIC_IP" # Replace with actual IP from Step 11
KEY="real-estate-key.pem"

# Create directory
ssh -i $KEY ubuntu@$IP "mkdir -p ~/real-state/docker-project/nginx/conf.d"

# SCP essential files
scp -i $KEY docker-compose.yml ubuntu@$IP:~/real-state/docker-project/
scp -i $KEY .env.production ubuntu@$IP:~/real-state/docker-project/
scp -i $KEY nginx/nginx.conf ubuntu@$IP:~/real-state/docker-project/nginx/
scp -i $KEY nginx/conf.d/default.conf ubuntu@$IP:~/real-state/docker-project/nginx/conf.d/
scp -i $KEY -r scripts/ ubuntu@$IP:~/real-state/docker-project/
```


### 2. Configure EC2 (SSH into Server)
```bash
ssh -i real-estate-key.pem ubuntu@<PUBLIC_IP>

# Navigate to project
cd ~/real-state/docker-project

# ==========================================================
# EBS MOUNTING & FSTAB CONFIGURATION
# ==========================================================

# 1. Identify devices (usually /dev/nvme1n1 and /dev/nvme2n1 on Nitro instances)
lsblk

# 2. Format disks (ONLY RUN THIS ONCE for new volumes!)
sudo mkfs -t ext4 /dev/nvme1n1  # Postgres volume
sudo mkfs -t ext4 /dev/nvme2n1  # SSL Certs volume

# 3. Create mount directories
sudo mkdir -p /mnt/ebs/postgres/data
sudo mkdir -p /mnt/ebs/certs

# 4. Get UUIDs of the new volumes
sudo blkid /dev/nvme1n1 /dev/nvme2n1

# 5. Add to /etc/fstab for persistent mounting
# Using your specific UUIDs:
# Postgres: b6a58cd1-2b6a-40ee-aabc-d678585f84e5
# SSL: fc78e49a-5a57-4a3e-b576-640d70e2dbb6

sudo vi  /etc/fstab
# Add these exact lines at the end:
UUID=b6a58cd1-2b6a-40ee-aabc-d678585f84e5  /mnt/ebs/postgres  ext4  defaults,nofail  0  2
UUID=fc78e49a-5a57-4a3e-b576-640d70e2dbb6  /mnt/ebs/certs     ext4  defaults,nofail  0  2

# OR run these commands to append them directly:
# echo 'UUID=b6a58cd1-2b6a-40ee-aabc-d678585f84e5  /mnt/ebs/postgres  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
# echo 'UUID=fc78e49a-5a57-4a3e-b576-640d70e2dbb6  /mnt/ebs/certs     ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab

# 6. Mount everything
sudo mount -a
sudo systemctl daemon-reload

# 7. Set permissions
sudo chown -R 999:999 /mnt/ebs/postgres/data
sudo chmod 700 /mnt/ebs/postgres/data
sudo chmod 755 /mnt/ebs/certs

# ==========================================================
# SWAP FILE CONFIGURATION (CRITICAL for t3.micro)
# ==========================================================

# 1. Create a 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 2. Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# ==========================================================
# INSTALLATION & STARTUP
# ==========================================================

# Run Automated Setup (Installs Docker & Certbot)
# Replace with your domain and email
sudo bash scripts/setup-all.sh test.plotchoice.com bhavsajan.realty@gmail.com

# Start Application
docker compose --env-file .env.production up -d
```



---

## 🔍 Part 3: Resource Inventory & Cleanup

### 1. List All Active Resources
You can use the inventory script to see exactly what you have running in `us-east-1`:

```bash
# From your local terminal
bash scripts/list-resources.sh
```

### 2. Cleanup (When done with testing)
If you want to delete everything to avoid costs, follow this order:
1.  **Terminate EC2**: `aws ec2 terminate-instances --instance-ids $INSTANCE_ID`
2.  **Delete Volumes**: `aws ec2 delete-volume --volume-id $VOL_DB`
3.  **Delete VPC**: (Requires deleting Subnets, IGW, and SG first)

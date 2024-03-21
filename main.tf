terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
 profile ="default"
 region  = "us-east-1"
}

resource "aws_vpc" "shiva_vpc" {
  cidr_block       = "10.20.0.0/16"
 enable_dns_support = true
 enable_dns_hostnames = true

  tags = {
    Name = "vpc"
  }
}

resource "aws_subnet" "shivapub_3" {
  vpc_id     = aws_vpc.shiva_vpc.id
  cidr_block = "10.20.4.0/24"

  tags = {
    Name = "shiva_public3"
  }
}
resource "aws_subnet" "shivapub_4" {
  vpc_id     = aws_vpc.shiva_vpc.id
  cidr_block = "10.20.5.0/24"

  tags = {
    Name = "shiva_public5"
  }
}

# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

# e.g., Create subnets in the first two available availability zones

resource "aws_subnet" "shivapub_1" {
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_id     = aws_vpc.shiva_vpc.id
  cidr_block = "10.20.1.0/24"

  # ...
}

resource "aws_subnet" "shivapub_2" {
  availability_zone = data.aws_availability_zones.available.names[1]
  vpc_id     = aws_vpc.shiva_vpc.id
  cidr_block = "10.20.32.0/24"

  # ...
}
#######################################################
resource "aws_iam_role" "myapp" {
  name = "eks-cluster-example"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.myapp.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.myapp.name
}
##########################################################
resource "aws_eks_cluster" "myapp" {
  name     = "myapp1"
  role_arn = aws_iam_role.myapp.arn

  vpc_config {
    subnet_id = [aws_subnet.shivapub_3.id, aws_subnet.shivapub_4.id, aws_subnet.shivapub_1.id, aws_subnet.shivapub_2.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.myapp.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.myapp.certificate_authority[0].data
}
##############################################################
resource "aws_iam_role" "myapp3" {
  name = "eks-node-group-example1"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.myapp3.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.myapp3.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.myapp3.name
}
############################################################
resource "aws_eks_node_group" "myapp4" {
  cluster_name    = aws_eks_cluster.myapp.name
  node_group_name = "example"
  node_role_arn   = aws_iam_role.myapp3.arn
  subnet_ids      = [aws_subnet.shivapub_3.id, aws_subnet.shivapub_2.id]

  ami_type = "AL2_x86_64"
  instance_types = ["t3.small"]
  
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }


  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}

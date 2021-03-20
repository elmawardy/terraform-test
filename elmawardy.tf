locals {
  cluster_name = "elmawardy-eks"
  helm_release_name = "elmawardy-terraform"
  helm_chart_name = "elmawardy-terraform"
  deployment_port = "8080"
  helm_chart_version = "0.1.1"
  helm_repo_url = "https://elmawardy.github.io/terraform-test/helm"
}

provider "aws" {
access_key = "<your access key>"
secret_key = "<your secret key>"
  region = "us-east-1"
}

data "aws_eks_cluster" "cluster" {
  name = module.my-eks-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.my-eks-cluster.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  vpc_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "my-eks-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.17"
  subnets         = module.vpc.public_subnets
  vpc_id          = module.vpc.vpc_id

  worker_groups = [
    {
      instance_type = "t2.medium"
      asg_max_size  = 1
      root_volume_type = "gp2"
    }
  ]
}


resource "helm_release" "elmawardy_terraform" {
  name       = local.helm_release_name
  chart      = "${local.helm_repo_url}/${local.helm_release_name}-${local.helm_chart_version}.tgz"

  set {
    name  = "cluster.enabled"
    value = "true"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
}


# data "aws_region" "current" {}
# data "aws_eks_cluster" "target" {
#   name = local.cluster_name
# }

# module "alb_ingress_controller" {
#   source  = "iplabs/alb-ingress-controller/kubernetes"
#   version = "3.1.0"

#   providers = {
#     kubernetes = "kubernetes.eks"
#   }

#   k8s_cluster_type = "eks"
#   k8s_namespace    = "kube-system"

#   aws_region_name  = data.aws_region.current.name
#   k8s_cluster_name = data.aws_eks_cluster.target.name
# }

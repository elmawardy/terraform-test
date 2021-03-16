locals {
  cluster_name = "elmawardy-eks"
  helm_release_name = "elmawardy-terraform"
  helm_chart_name = "elmawardy-terraform"
  helm_chart_version = "0.1.0"
  helm_repo_url = "https://elmawardy.github.io/terraform/charts"
}

provider "aws" {
access_key = "<your access key>"
secret_key = "<your secret key>"
  region = "us-east-1"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
}


module "vpc" {
  source = "git::ssh://git@github.com/reactiveops/terraform-vpc.git?ref=v5.0.1"
  name = "${local.cluster_name}-vpc"

  aws_region = "us-east-1"
  az_count   = 3
  aws_azs    = "us-east-1a, us-east-1b, us-east-1c"

  global_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "eks" {
  source       = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v12.1.0"
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.aws_vpc_id
  subnets      = module.vpc.aws_subnet_private_prod_ids

  node_groups = {
    eks_nodes = {
      desired_capacity = 3
      max_capacity     = 3
      min_capaicty     = 3

      instance_type = "t2.small"
    }
  }

  manage_aws_auth = false
}


resource "helm_release" "elmawardy_terraform" {
  name       = local.helm_release_name
  repository = local.helm_repo_url
  chart      = local.helm_chart_name
  version    = local.helm_chart_version

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
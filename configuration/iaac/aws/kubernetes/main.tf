# aws --version
# aws eks --region us-east-1 update-kubeconfig --name deekay-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-deekay-devops

terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

module "deekay-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  cluster_name    = "deekay-cluster"
  cluster_version = "1.27"
  subnet_ids = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id

  #vpc_id         = "vpc-0db0156491661a2ae"

  eks_managed_node_groups = {
    default = {
      instance_types = ["t2.micro"]
      min_size       = 3
      max_size       = 5
      desired_size   = 3
    }
  } 
}

data "aws_eks_cluster" "cluster" {
  name = module.deekay-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.deekay-cluster.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}


# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
provider "aws" {
  region  = "us-east-1"
}
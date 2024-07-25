# aws --version
# aws eks --region us-east-2 update-kubeconfig --name deekay-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-deekay-devops-practice

terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-2"
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  version                = "~> 2.12"
}

module "deekay-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "deekay-cluster"
  cluster_version = "1.14"
  subnets         = ["subnet-08f896948f3eb7964", "subnet-0142e886a0ec305a5", "subnet-05c48f02ac9d9a945"]
  #subnets = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id

  #vpc_id         = "vpc-01771d6c74d7ea7aa"

  node_groups = [
    {
      instance_type = "t2.micro"
      max_capacity  = 5
      desired_capacity = 3
      min_capacity  = 3
    }
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.deekay-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.deekay-cluster.cluster_id
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
  region  = "us-east-2"
}
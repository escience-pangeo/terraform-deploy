resource "aws_efs_file_system" "home_dirs" {
  tags = {
    Name = "${var.cluster_name}-home-dirs"
  }
}


resource "aws_security_group" "home_dirs_sg" {
  name   = "home_dirs_sg"
  vpc_id = module.vpc.vpc_id

  # NFS
  ingress {

    # FIXME: Is ther a way to do this without CIDR block copy/pasta
    cidr_blocks = [ "172.16.0.0/16"]
    # FIXME: Do we need this security_groups here along with cidr_blocks
    security_groups = [ module.eks.worker_security_group_id ]
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
  }

  tags = {
    Owner = split("/", data.aws_caller_identity.current.arn)[1]
    AutoTag_Creator = data.aws_caller_identity.current.arn
  }
}

resource "aws_efs_mount_target" "home_dirs_targets" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.home_dirs.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [ aws_security_group.home_dirs_sg.id ]
}

resource "kubernetes_namespace" "support" {
  metadata {
    name = "support"
  }
}

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "staging"
  }
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}

resource "helm_release" "efs-provisioner" {
  name       = "efs-provisioner"
  namespace  = kubernetes_namespace.support.metadata.0.name
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "efs-provisioner"
  version    = "0.11.0"

  set{
    name  = "efsProvisioner.efsFileSystemId"
    value = aws_efs_file_system.home_dirs.id
  }

  set {
      name  = "efsProvisioner.awsRegion"
      value = var.region
  }

  set {
      # We don't entirely know the effects of dynamic gid allocation,
      # particularly on the ability to re-use EFS when we recreate
      # clusters. Turn it off for now.
      name  = "efsProvisioner.storageClass.gidAllocate.enabled"
      value = false
  }

  set {
    name  = "efsProvisioner.path"
    value = "/"
  }

  set {
    name  = "efsProvisioner.provisionerName"
    value = "aws.amazon.com/efs"
  }
}

resource "kubernetes_persistent_volume" "shared-efs-volume" {
  metadata {
    name = "staging-shared-nfs"
  }

  spec {
    capacity = {
      storage = "1Mi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      nfs {
        server = aws_efs_file_system.home_dirs.dns_name
        path = "/"
      }
    }
    storage_class_name = "manual-sc"
  }
}

resource "kubernetes_persistent_volume_claim" "shared-efs-claim" {
  metadata {
    name = "shared-nfs"
    namespace = "staging"
  }

  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Mi"
      }
    }
    volume_name = kubernetes_persistent_volume.shared-efs-volume.metadata.0.name
    storage_class_name = "manual-sc"
  }
}

resource "kubernetes_persistent_volume" "shared-efs-volume-prod" {
  metadata {
    name = "prod-shared-nfs"
  }

  spec {
    capacity = {
      storage = "1Mi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      nfs {
        server = aws_efs_file_system.home_dirs.dns_name
        path = "/"
      }
    }
    storage_class_name = "manual-sc"
  }
}

resource "kubernetes_persistent_volume_claim" "shared-efs-claim-prod" {
  metadata {
    name = "shared-nfs"
    namespace = "prod"
  }

  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Mi"
      }
    }
    volume_name = kubernetes_persistent_volume.shared-efs-volume-prod.metadata.0.name
    storage_class_name = "manual-sc"
  }
}

locals {
  cluster_name         = "ecs"
  private_subnet_ids = [
    for subnet in aws_subnet.private_az :
    subnet.id
  ]
}

resource "aws_security_group" "ecs" {
  name   = "ECS-common-sg"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_all" {
  security_group_id = aws_security_group.ecs.id
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_iam_policy_document" "ec2_managed_infra_role" {
  statement {
    sid    = "AllowECSAssumeRole"
    effect = "Allow"
    principals {
      identifiers = ["ecs.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }

}

resource "aws_iam_role" "ec2_managed_instances_infra_role" {
  name               = "ec2-managed-instances-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_managed_infra_role.json
}

data "aws_iam_policy" "ecs_ec2_managed_instance_policy" {
  name = "AmazonECSInfrastructureRolePolicyForManagedInstances"
}

resource "aws_iam_role_policy_attachment" "ec2_managed_instances_infra_role_default_policy_attachment" {
  role       = aws_iam_role.ec2_managed_instances_infra_role.name
  policy_arn = data.aws_iam_policy.ecs_ec2_managed_instance_policy.arn
}

data "aws_iam_policy_document" "ec2_managed_instances_infra" {
  statement {
    sid    = "AllowPassManagedInstanceProfile"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ec2_managed_instance_profile.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ec2_managed_instances_infra" {
  name   = "ec2-managed_instances_infra_role"
  role   = aws_iam_role.ec2_managed_instances_infra_role.id
  policy = data.aws_iam_policy_document.ec2_managed_instances_infra.json
}

data "aws_iam_policy_document" "ec2_managed_instance_profile" {
  statement {
    sid    = "AllowECSAssumeRole"
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_managed_instance_profile" {
  name               = "managed-instance-profile"
  assume_role_policy = data.aws_iam_policy_document.ec2_managed_instance_profile.json
}

data "aws_iam_policy" "ec2_managed_instance_profile_policy" {
  name = "AmazonECSInstanceRolePolicyForManagedInstances"
}

resource "aws_iam_role_policy_attachment" "ec2_managed_instance_profile" {
  role       = aws_iam_role.ec2_managed_instance_profile.id
  policy_arn = data.aws_iam_policy.ec2_managed_instance_profile_policy.arn
}

resource "aws_iam_instance_profile" "ecs_managed_instance_profile" {
  name = "ecs-managed-instance-profile"
  role = aws_iam_role.ec2_managed_instance_profile.name
}

data "aws_iam_policy_document" "ecs_managed_instances_pass_role" {
  statement {
    sid    = "AllowPassInstanceProfileRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ec2_managed_instance_profile.arn
    ]
  }
}

resource "aws_iam_role_policy" "ecs_managed_instance_profile_assume" {
  name   = "ecs-managed-instances-passrole"
  role   = aws_iam_role.ec2_managed_instances_infra_role.id
  policy = data.aws_iam_policy_document.ecs_managed_instances_pass_role.json
}

data "aws_iam_policy" "ecs_execution" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_execution" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = data.aws_iam_policy.ecs_execution.arn
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid     = "AllowEcsTask"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "GitHubActionAllowDescribeECSTaskDefinitions"
    effect    = "Allow"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "app" {
  name   = "ecs"
  policy = data.aws_iam_policy_document.app.json
}

data "aws_iam_policy_document" "github" {
  statement {

  }
}

resource "aws_iam_role" "github" {
  name               = "GitHubRole"
  assume_role_policy = data.aws_iam_policy_document.github.json
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.github.id
  policy_arn = aws_iam_policy.app.arn
}

resource "aws_ecs_cluster" "ecs" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_capacity_provider" "ecs" {
  name    = "managed-ec2"
  cluster = aws_ecs_cluster.ecs.name
  managed_instances_provider {
    infrastructure_role_arn = aws_iam_role.ec2_managed_instances_infra_role.arn
    instance_launch_template {
      ec2_instance_profile_arn = aws_iam_instance_profile.ecs_managed_instance_profile.arn
      monitoring               = "DETAILED"
      network_configuration {
        subnets         = local.private_subnet_ids
        security_groups = [aws_security_group.ecs.id]
      }
      storage_configuration {
        storage_size_gib = 10
      }

    }
    propagate_tags = "NONE"
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs" {
  cluster_name       = aws_ecs_cluster.ecs.name
  capacity_providers = [aws_ecs_capacity_provider.ecs.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_task_definition" "ecs_base" {
  container_definitions = jsonencode([
    {
      name      = "ecs"
      image     = "nginx:latest"
      cpu       = 256
      memory    = 512
      essential = true
    }
  ])
  family                   = "ecs"
  requires_compatibilities = ["MANAGED_INSTANCES"]
  network_mode             = "host"
  track_latest             = true
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size
  cpu                = 512
  memory             = 1024
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
  lifecycle {
    ignore_changes = [arn]
  }
}

resource "aws_ecs_service" "ecs" {
  name = "ecs"
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
    base              = 1
  }
  desired_count        = 1
  task_definition      = aws_ecs_task_definition.ecs_base.arn
  cluster              = aws_ecs_cluster.ecs.id
  force_new_deployment = true
}

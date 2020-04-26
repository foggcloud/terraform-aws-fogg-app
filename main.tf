locals {
  name = format("%s", var.name)
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "this" {
  for_each = toset(var.subnet_ids)

  id = each.value
}

data "aws_kms_alias" "efs" {
  name = "alias/aws/elasticfilesystem"
}


resource "aws_efs_file_system" "this" {
  encrypted  = true
  kms_key_id = data.aws_kms_alias.efs.target_key_id

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.this[each.value].id]
}

resource "aws_security_group" "this" {
  for_each = toset(var.subnet_ids)

  name   = format("%s-%s", local.name, each.value)
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "nfs" {
  for_each = toset(var.subnet_ids)

  type              = "ingress"
  protocol          = "tcp"
  from_port         = 2049
  to_port           = 2049
  cidr_blocks       = [data.aws_subnet.this[each.value].cidr_block]
  security_group_id = aws_security_group.this[each.value].id
}

resource "aws_security_group_rule" "egress" {
  for_each = toset(var.subnet_ids)

  type              = "egress"
  protocol          = "all"
  from_port         = -1
  to_port           = 0
  cidr_blocks       = [data.aws_subnet.this[each.value].cidr_block]
  security_group_id = aws_security_group.this[each.value].id
}

resource "aws_ecs_cluster" "this" {
  name = local.name
}

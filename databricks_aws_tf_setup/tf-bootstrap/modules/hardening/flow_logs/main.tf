resource "aws_cloudwatch_log_group" "flow" {
  name              = "/vpc/flow/${var.vpc_id}"
  retention_in_days = 180
  tags = var.tags
}

resource "aws_iam_role" "flow" {
  name = "vpc-flowlogs-${var.vpc_id}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow" {
  name = "vpc-flowlogs-policy"
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flow.arn
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id
}

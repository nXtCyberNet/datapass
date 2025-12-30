resource "aws_iam_policy" "datatakerpolicy" {
  name        = "lambda-datataker-full-policy"
  description = "Permissions for DataTaker Lambda: VPC, S3, SNS, and Logging"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      },


      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.bucket.arn,      # Access to the bucket itself (for listing)
          "${aws_s3_bucket.bucket.arn}/*" # Access to all files inside
        ]
      },

      
      {
        Effect = "Allow",
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes",
          "sns:ListTopics"
        ],
        Resource = aws_sns_topic.data_updates.arn
      },

      
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

  


resource "aws_sns_topic" "data_updates" {
  name = "pipeline-updates-topic"
} 

resource "aws_cloudwatch_event_rule" "every_30_min" {
  name                = "every-30-minutes"
  description         = "Fires every 30 minutes"
  schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "trigger_datataker" {
  rule      = aws_cloudwatch_event_rule.every_30_min.name
  target_id = "datataker_lambda"
  arn       = aws_lambda_function.datataker.arn
}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.datataker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_30_min.arn
}


resource "aws_sns_topic_subscription" "summery_subscription" {
  topic_arn = aws_sns_topic.data_updates.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.summery.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summery.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.data_updates.arn
}


resource "aws_lambda_function" "datataker" {
    function_name = "data-taker"
    role = aws_iam_role.datatakerrole.arn
    package_type = "Image"
    image_uri = "${aws_ecr_repository.datataker.repository_url}:${var.image_tag}"
    memory_size = 1024
    
    depends_on = [null_resource.build_and_push_lambdacontainers]
    vpc_config {
        subnet_ids = [
            aws_subnet.private.id
        ]
        security_group_ids = [ aws_security_group.lambda_sg.id]
    }
    environment {
    variables = {
      BUCKET_NAME   = aws_s3_bucket.bucket.bucket
      SNS_TOPIC_ARN = aws_sns_topic.data_updates.arn
      
    }
  }

}

resource "aws_ecr_repository" "datataker" {
  name = "datataker" 
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

resource "aws_ecr_repository" "summery1" {
  name = "summery" 
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}


resource "aws_lambda_function" "summery" {
    function_name = "summery"
    role = aws_iam_role.datatakerrole.arn
    package_type = "Image"
    image_uri = "${aws_ecr_repository.summery1.repository_url}:${var.image_tag}"
    timeout = 30
    memory_size = 1024
    depends_on = [null_resource.build_and_push_lambdacontainers]
    vpc_config {
        subnet_ids = [
            aws_subnet.private.id
        ]
        security_group_ids = [ aws_security_group.lambda_sg.id]
    }

  
}

resource "aws_security_group" "lambda_sg" {
  name   = "lambda-sg"
  vpc_id = aws_vpc.datapipeline.id

  # No inbound rules

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "datapipeline-"

  tags = {
    Name = "data-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_eip" "nat" {
  domain = "vpc"
}





resource "aws_iam_role" "datatakerrole" {
  name = "data-taker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.datatakerrole.name
  policy_arn = aws_iam_policy.datatakerpolicy.arn
}


resource "null_resource" "build_and_push_lambdacontainers" {
  triggers = { always_run = timestamp() }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      aws ecr get-login-password --region us-east-1 \
      | docker login --username AWS --password-stdin ${aws_ecr_repository.datataker.repository_url}

      
      docker build -t ${aws_ecr_repository.datataker.repository_url}:${var.image_tag} ../lamda/datataker
      docker push ${aws_ecr_repository.datataker.repository_url}:${var.image_tag}
      aws ecr get-login-password --region us-east-1 \
      | docker login --username AWS --password-stdin ${aws_ecr_repository.summery1.repository_url}
      
      docker build -t ${aws_ecr_repository.summery1.repository_url}:${var.image_tag} ../lamda/summery
      docker push ${aws_ecr_repository.summery1.repository_url}:${var.image_tag}

    EOT
  }
}




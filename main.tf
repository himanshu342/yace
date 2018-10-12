data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

// Dynamo DB

resource "aws_dynamodb_table" "db" {
  name = "${var.name}"
  read_capacity = "1"
  write_capacity = "1"
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = "${var.enable_auto_backup}"
  }

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }
}

module "dynamodb_autoscaler" {
  source = "git::https://github.com/cloudposse/terraform-aws-dynamodb-autoscaler.git?ref=tags/0.2.4"
  namespace = "yace"
  stage = "prod"
  name = "${var.name}"
  dynamodb_table_name = "${aws_dynamodb_table.db.id}"
  dynamodb_table_arn = "${aws_dynamodb_table.db.arn}"
  autoscale_write_target = 75
  autoscale_read_target = 75
  autoscale_min_read_capacity = 1
  autoscale_max_read_capacity = 10
  autoscale_min_write_capacity = 1
  autoscale_max_write_capacity = 10
}

// Lambda function putComment
// Adapted after https://gist.github.com/smithclay/e026b10980214cbe95600b82f67b4958 and https://www.terraform.io/docs/providers/aws/guides/serverless-with-aws-lambda-and-api-gateway.html

module "lambda_zip_put_comment" {
  source = "github.com/2uinc/terraform-package-lambda"
  code = "${path.module}/lambda/putComment/index.js"
}

resource "aws_lambda_function" "put_comment" {
  filename = "${module.lambda_zip_put_comment.output_filename}"
  function_name = "put_comment"
  role = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "index.putComment"
  source_code_hash = "${module.lambda_zip_put_comment.output_base64sha256}"
  runtime = "nodejs8.10"
  timeout = 5

  environment {
    variables = {
      INSTANCE_NAME = "${var.name}",
      SERVICE_URL = "${var.service_url}",
      CORS_ALLOWED_ORIGIN = "${var.cors_allowed_origin}",
      TABLE = "${aws_dynamodb_table.db.id}",
      TOKEN_RECIPIENTS = "${var.token_recipients}",
      TOKEN_SENDER = "${var.token_sender}",
      SMTP_HOST = "${var.smtp_host}",
      SMTP_PORT = "${var.smtp_port}",
      SMTP_SECURE = "${var.smtp_secure}",
      SMTP_USER = "${var.smtp_user}",
      SMTP_PASSWORD = "${var.smtp_password}",
    }
  }
}

resource "aws_lambda_permission" "put_comment" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.put_comment.arn}"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_deployment.api.execution_arn}/*/*"
}

// Lambda function getComments

module "lambda_zip_get_comments" {
  source = "github.com/2uinc/terraform-package-lambda"
  code = "${path.module}/lambda/getComments/index.js"
}

resource "aws_lambda_function" "get_comments" {
  filename = "${module.lambda_zip_get_comments.output_filename}"
  function_name = "get_comments"
  role = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "index.getComments"
  source_code_hash = "${module.lambda_zip_get_comments.output_base64sha256}"
  runtime = "nodejs8.10"

  environment {
    variables = {
      TABLE = "${aws_dynamodb_table.db.id}",
      CORS_ALLOWED_ORIGIN = "${var.cors_allowed_origin}"
    }
  }
}

resource "aws_lambda_permission" "get_comments" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.get_comments.arn}"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_deployment.api.execution_arn}/*/*"
}

// Lambda function acceptComment

module "lambda_zip_accept_comment" {
  source = "github.com/2uinc/terraform-package-lambda"
  code = "${path.module}/lambda/acceptComment/index.js"
}

resource "aws_lambda_function" "accept_comment" {
  filename = "${module.lambda_zip_accept_comment.output_filename}"
  function_name = "accept_comment"
  role = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "index.acceptComment"
  source_code_hash = "${module.lambda_zip_accept_comment.output_base64sha256}"
  runtime = "nodejs8.10"

  environment {
    variables = {
      TABLE = "${aws_dynamodb_table.db.id}"
    }
  }
}

resource "aws_lambda_permission" "accept_comment" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.accept_comment.arn}"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_deployment.api.execution_arn}/*/*"
}

// API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name = "${var.name}"
}

resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    "aws_api_gateway_integration.put_comment",
    "aws_api_gateway_integration.get_comments",
    "aws_api_gateway_integration.accept_comment"
  ]

  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name = "prod"
}

// > putComment

resource "aws_api_gateway_method" "put" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "put_comment" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_method.put.resource_id}"
  http_method = "${aws_api_gateway_method.put.http_method}"

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.put_comment.invoke_arn}"
}

// >> CORS

module "put_comment_cors" {
  source = "github.com/squidfunk/terraform-aws-api-gateway-enable-cors"
  version = "0.1.0"

  api_id = "${aws_api_gateway_rest_api.api.id}"
  api_resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  allowed_origin = "${var.cors_allowed_origin}"
}

resource "aws_api_gateway_method_response" "put_comment" {
    rest_api_id = "${aws_api_gateway_rest_api.api.id}"
    resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
    http_method = "${aws_api_gateway_method.put.http_method}"
    status_code = "200"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = ["module.put_comment_cors"]
}

// > getComments

resource "aws_api_gateway_resource" "pre_get_comments" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "get"
}

resource "aws_api_gateway_resource" "get_comments" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.pre_get_comments.id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.get_comments.id}"
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_comments" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.get_comments.id}"
  http_method = "${aws_api_gateway_method.get.http_method}"

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.get_comments.invoke_arn}"
}

// >> CORS

module "get_comments_cors" {
  source = "github.com/squidfunk/terraform-aws-api-gateway-enable-cors"
  version = "0.1.0"

  api_id = "${aws_api_gateway_rest_api.api.id}"
  api_resource_id = "${aws_api_gateway_resource.get_comments.id}"
  allowed_origin = "${var.cors_allowed_origin}"
}

resource "aws_api_gateway_method_response" "get_comments" {
    rest_api_id = "${aws_api_gateway_rest_api.api.id}"
    resource_id = "${aws_api_gateway_resource.get_comments.id}"
    http_method = "${aws_api_gateway_method.get.http_method}"
    status_code = "200"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = ["module.get_comments_cors"]
}

// > acceptComment

resource "aws_api_gateway_resource" "pre1_accept_comment" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "token"
}

resource "aws_api_gateway_resource" "pre2_accept_comment" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.pre1_accept_comment.id}"
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "accept_comment" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_resource.pre2_accept_comment.id}"
  path_part   = "{token}"
}

resource "aws_api_gateway_method" "accept" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.accept_comment.id}"
  http_method = "GET"
  authorization = "NONE"

  request_parameters {
    "method.request.path.id" = true
    "method.request.path.token" = true
  }
}

resource "aws_api_gateway_integration" "accept_comment" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.accept_comment.id}"
  http_method = "${aws_api_gateway_method.accept.http_method}"

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.accept_comment.invoke_arn}"

  request_parameters {
    "integration.request.path.id" = "method.request.path.id"
    "integration.request.path.token" = "method.request.path.token"
  }
}

// IAM

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.json}"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda_dynamodb"
  role = "${aws_iam_role.iam_for_lambda.name}"
  policy = "${data.aws_iam_policy_document.lambda_dynamodb.json}"
}

data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.db.id}"
    ]
  }
}


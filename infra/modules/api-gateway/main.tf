resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.api_name}"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.api_name}-vpc-link"
  security_group_ids = var.security_group_ids
  subnet_ids         = var.subnet_ids
}

resource "aws_apigatewayv2_integration" "this" {
  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.this.id
}

resource "aws_apigatewayv2_route" "get_claim" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /claims/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_route" "post_summarize" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /claims/{id}/summarize"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = var.cloudwatch_log_group_arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

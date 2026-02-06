resource "aws_lb" "this" {
  name               = var.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "this" {
  name        = "${var.nlb_name}-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = 8080
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

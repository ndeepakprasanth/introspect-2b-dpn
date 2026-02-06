output "nlb_arn" {
  value = aws_lb.this.arn
}

output "nlb_dns_name" {
  value = aws_lb.this.dns_name
}

output "listener_arn" {
  value = aws_lb_listener.this.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

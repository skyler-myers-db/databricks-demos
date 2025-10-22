# Private hosted zone for front-end PrivateLink DNS mapping. citeturn15view0
resource "aws_route53_zone" "pl" {
  name = var.domain_name
  vpc { vpc_id = var.vpc_id }
}

# A record mapping <deployment>.cloud.databricks.com -> VPCE private IPs
resource "aws_route53_record" "ws_a" {
  zone_id = aws_route53_zone.pl.zone_id
  name    = var.workspace_deployment_fqdn
  type    = "A"
  ttl     = 60
  records = var.vpce_ips
}

# CNAME mapping dbc-dp-<workspace-id> -> <deployment>.cloud.databricks.com
resource "aws_route53_record" "dp_cname" {
  zone_id = aws_route53_zone.pl.zone_id
  name    = var.workspace_dp_cname
  type    = "CNAME"
  ttl     = 60
  records = [var.workspace_deployment_fqdn]
}

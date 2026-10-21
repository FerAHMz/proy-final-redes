# DNS privado (Fase 2): zona barrilete.dev de Route 53 que solo existe dentro
# de la VPC. La intranet se accede por nombre, no por IP.

resource "aws_route53_zone" "private" {
  name    = "barrilete.dev"
  comment = "Zona privada de Barrilete Ventures"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = { Name = "${local.name}-private-zone" }
}

# El SOA por defecto guarda las respuestas negativas 1 día (86400 s). Si una
# instancia pregunta mientras la zona recién creada se propaga, se quedaría sin
# resolver el nombre todo ese tiempo; con 60 s se corrige solo.
# ns-1536.awsdns-00.co.uk es el servidor primario fijo de las zonas privadas.
resource "aws_route53_record" "soa" {
  zone_id         = aws_route53_zone.private.zone_id
  name            = aws_route53_zone.private.name
  type            = "SOA"
  ttl             = 60
  allow_overwrite = true
  records         = ["ns-1536.awsdns-00.co.uk. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 60"]
}

resource "aws_route53_record" "rrhh" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "rrhh.barrilete.dev"
  type    = "A"
  ttl     = 300
  records = [aws_instance.datacenter[0].private_ip]

  depends_on = [aws_route53_record.soa]
}

resource "aws_route53_record" "ldap" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "ldap.barrilete.dev"
  type    = "A"
  ttl     = 300
  records = [local.ldap_ip]

  depends_on = [aws_route53_record.soa]
}

# CA propia del laboratorio y certificado del servidor LDAP (LDAPS).
# Las llaves privadas solo viven en el state, que no se versiona.

locals {
  # IP fija del servidor LDAP en el Data Center (también va en el certificado)
  ldap_ip = cidrhost(var.datacenter_subnet_cidr, 10)
}

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 8760
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name  = "Barrilete Ventures CA"
    organization = "Barrilete Ventures"
  }
}

resource "tls_private_key" "ldap" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Vale para el nombre y para la IP, así los clientes pueden usar cualquiera
resource "tls_cert_request" "ldap" {
  private_key_pem = tls_private_key.ldap.private_key_pem
  dns_names       = ["ldap.barrilete.dev"]
  ip_addresses    = [local.ldap_ip]

  subject {
    common_name  = "ldap.barrilete.dev"
    organization = "Barrilete Ventures"
  }
}

resource "tls_locally_signed_cert" "ldap" {
  cert_request_pem      = tls_cert_request.ldap.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

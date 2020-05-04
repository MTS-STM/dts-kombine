provider "azurerm" {
  version = "~> 2.0.0"
  features {}
  subscription_id = var.SUBSCRIPTION_ID
  tenant_id = var.TENANT_ID
  client_id = var.CLIENT_ID
  client_secret = var.CLIENT_SECRET
}

resource "azurerm_resource_group" "main" {
  name     = var.KOMBINE_RG_NAME
  location = var.LOCATION
  tags = {
    Environment = var.TERRAFORM_ENVIRONMENT_NAME
    Terraform = "True"
    Branch = "IITB"
    Classification = var.CLASSIFICATION
    Directorate = "BSIM"
    Project = "DTS"
  }
}

resource "azurerm_resource_group" "data" {
  name     = var.KOMBINE_DATA_RG_NAME
  location = azurerm_resource_group.main.location
  tags = {
    Environment = var.TERRAFORM_ENVIRONMENT_NAME
    Terraform = "True"
    Branch = "IITB"
    Classification = var.CLASSIFICATION
    Directorate = "BSIM"
    Project = "DTS"
  }
}

resource "azurerm_virtual_network" "k8svnet" {
  name                = azurerm_resource_group.main.name
  address_space       = var.VNET_ADDRESS_SPACE
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = {
    environment = var.TERRAFORM_ENVIRONMENT_NAME
    Terraform = "True"
    Branch = "IITB"
    Classification = var.CLASSIFICATION
    Directorate = "BSIM"
    Project = "DTS"
  }
}
resource "azurerm_subnet" "k8sVMSubnet" {
  name                 = "k8s-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.k8svnet.name
  address_prefix = var.K8S_VNET_ADDRESS_PREFIX

}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${azurerm_resource_group.main.name}-K8S"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = azurerm_resource_group.main.name
  api_server_authorized_ip_ranges = []
  enable_pod_security_policy = false


  role_based_access_control {
    enabled         = "true"
  }

  default_node_pool {
    name       = "default"
    node_count = var.K8_AGENT_COUNT
    vm_size    = var.K8_AGENT_SIZE
    os_disk_size_gb = 60
    vnet_subnet_id  = azurerm_subnet.k8sVMSubnet.id
    availability_zones = []
    enable_auto_scaling = false
    enable_node_public_ip = false
    node_taints = []

  }
    linux_profile {
        admin_username  = "dtsadmin"
        ssh_key {
          key_data = var.SSH_PUB
        }
    }  

#    windows_profile {
#          admin_username = "azureuser" 
#    }

    network_profile {
      network_plugin = "azure"
      dns_service_ip = var.K8_DNS_IP
      docker_bridge_cidr = var.K8_DOCKER_BRIDGE_CIDR
      service_cidr = var.K8_SERVICE_CIDR

    }

  service_principal {
    client_id     = var.K8_CLUSTER_SP_ID
    client_secret = var.K8_CLUSTER_SP_PASS
  }

  tags = {
    Environment = var.TERRAFORM_ENVIRONMENT_NAME
    Terraform = "True"
    Branch = "IITB"
    Classification = var.CLASSIFICATION
    Directorate = "BSIM"
    Project = "DTS"
  }
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "${var.KEYVAULT_NAME}-${var.TERRAFORM_ENVIRONMENT_NAME}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.TENANT_ID

 sku_name = "standard"

  tags = {
    environment = var.TERRAFORM_ENVIRONMENT_NAME
    Terraform = "True"
    Branch = "IITB"
   Classification = var.CLASSIFICATION
    Directorate = "BSIM"
    Project = "DTS"
  }
}
s
resource "tls_private_key" "kombine-tls-key" {
  algorithm = "ECDSA"
}

resource "tls_self_signed_cert" "kombine-tls-cert" {
  key_algorithm   = tls_private_key.kombine-tls-key.algorithm
  private_key_pem = tls_private_key.kombine-tls-key.private_key_pem
  validity_period_hours = 8760
  early_renewal_hours = 3
  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
      "key_encipherment",
      "digital_signature",
      "server_auth",
  ]
  subject {
      common_name  = "graylog.marcusrd.dts-stn.com"
      organization = "DTS-STN"
  }
}

resource "azurerm_key_vault_certificate" "kombine-example-cert" {
  name         = "kombine-example-cert"
  key_vault_id = azurerm_key_vault.keyvault.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = ["dts.stn.com"]
      }

      subject            = "CN=dts-stn.com"
      validity_in_months = 12
    }
  }
}

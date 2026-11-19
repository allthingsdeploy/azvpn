variable "admin_ssh_public_key" {
  description = "SSH public key for the WireGuard server administrator."
  type        = string
  sensitive   = true
}

resource "azurerm_public_ip" "vpn" {
  name                = "pip-mxc-wireguard"
  location            = data.azurerm_resource_group.mexico.location
  resource_group_name = data.azurerm_resource_group.mexico.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "vpn" {
  name                = "nsg-mxc-wireguard"
  location            = data.azurerm_resource_group.mexico.location
  resource_group_name = data.azurerm_resource_group.mexico.name

  security_rule {
    name                       = "AllowSshFromAdminRange"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "40.77.167.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowWireGuard"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vpn" {
  name                  = "nic-mxc-wireguard"
  location              = data.azurerm_resource_group.mexico.location
  resource_group_name   = data.azurerm_resource_group.mexico.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vpn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vpn.id
  }
}

resource "azurerm_network_interface_security_group_association" "vpn" {
  network_interface_id      = azurerm_network_interface.vpn.id
  network_security_group_id = azurerm_network_security_group.vpn.id
}

resource "azurerm_linux_virtual_machine" "vpn" {
  name                            = "vm-mxc-wireguard"
  location                        = data.azurerm_resource_group.mexico.location
  resource_group_name             = data.azurerm_resource_group.mexico.name
  size                            = "Standard_B2s_v2"
  admin_username                  = "wireguard"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vpn.id]
  custom_data = base64encode(<<-CLOUD_INIT
    #cloud-config
    package_update: true
    packages:
      - wireguard
      - iptables
    runcmd:
      - [ bash, -lc, "printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-wireguard.conf && sysctl --system" ]
      - [ bash, -lc, "umask 077; wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key" ]
      - [ bash, -lc, "printf '[Interface]\nAddress = 10.2.0.1/24\nListenPort = 51820\nPrivateKey = %s\nPostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE\nPostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE\n' "'$(cat /etc/wireguard/server_private.key)'" > /etc/wireguard/wg0.conf" ]
      - [ bash, -lc, "chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/server_private.key /etc/wireguard/server_public.key" ]
      - [ systemctl, enable, --now, wg-quick@wg0 ]
  CLOUD_INIT
  )

  admin_ssh_key {
    username   = "wireguard"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

output "wireguard_public_ip" {
  description = "Public IP address of the WireGuard server."
  value       = azurerm_public_ip.vpn.ip_address
}

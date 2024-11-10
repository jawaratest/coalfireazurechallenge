provider "azurerm {
    features {}
}

resource "azurerm_resource_group" "rg" {
	name                = "CoalFireRG"
	location            = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
	name                = "CoalFire-vnet"
	location            = azurerm_resource_group.rg.location
	resource_group_name = azurerm_resource_group.rg.name
	address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
	name                 = "subnet1"
	resource_group_name  = azurerm_resource_group.rg.name
	virtual_network_name = azurerm_virtual_network.vnet.name
	address_prefixes     = ["10.0.0.0\24"]
}

resource "azurerm_subnet" "subnet" {
	name                 = "subnet2"
	resource_group_name  = azurerm_resource_group.rg.name
	virtual_network_name = azurerm_virtual_network.vnet.name
	address_prefixes     = ["10.0.1.0\24"]
}

resource "azurerm_subnet" "subnet" {
	name                 = "subnet3"
	resource_group_name  = azurerm_resource_group.rg.name
	virtual_network_name = azurerm_virtual_network.vnet.name
	address_prefixes     = ["10.0.2.0\24"]
}

resource "azurerm_subnet" "subnet" {
	name                 = "subnet4"
	resource_group_name  = azurerm_resource_group.rg.name
	virtual_network_name = azurerm_virtual_network.vnet.name
	address_prefixes     = ["10.0.3.0\24"]
}

resource "azurerm_network_interface" "nic" {
	count                = 3
        name                 = "${var.network_interface_name}${count.index}"
	location             = azurerm_resource_group.rg.location
	resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_public_ip" "ipaddress" {
	name = "coalfireips"
	location = azurerm_resource_group.rg.location
	resource_group_name = azurerm_resource_group.rg.name
	allocation_method = "Dynamic"
}

resource "azurerm_availability_set" "availabilityset" {
        name                = "coalfire-aset"
        location            = azurerm_resource_group.rg.location
        resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "coalfire-test"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
	count                 = 2
        name                  = "${var.virtual_machine_name}${count.index}"
	location              = azurerm_resource_group.rg.location
	resource_group_name   = azurerm_resource_group.rg.name
        network_interface_ids = [azurerm_network_interface.nic[count.index].id]
	vm_size               = "Standard_DS1_v2"

source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
	
storage_os_disk {
	name                  = "${var.disk_name}${count.index}"
        caching               = "ReadWrite"
        create_option         =  "FromImage"
        storage_account_type  = "Standard_LRS"
     }
   }
}

resource "azurerm_virtual_machine" "apache_terraform_site" {
        name                          = "${var.hostname}-site"
	location                      = var.location
	resource_group_name           = azurerm_resource_group.rg.name
        network_interface_ids         = [azurerm_network_interface.apache_terraform_nic.id]
	vm_size                       = "Standard_DS1_v2"
	delete_os_disk_on_termination = "true"

storage_image_reference {
	publisher             = var.image_publisher
	offer                 = var.image_offer
	sku                   = var.image_sku
	version               = var.image_version
	
storage_os_disk {
	name                  = "${var.hostname}_osdisk"
        caching               = "ReadWrite"
        create_option         =  "FromImage"
	storage_account_type  = "Standard_LRS"

os_profile {
	computer_name   = var.hostname
	admin_username  = var.admin_username
	admin_password  = var.admin_password

os_profile_linux_config {
	disable_password_authentication  = true
	ssh-keys {
	   path                          =  "/home/${var.admin_username}/.ssh/authorized_keys
	   key_data                      = file("~/.ssh/id_rsa.pub")
	         }
             }
         }
     }
  }
}

provisioner "remote-exec {
	inline          = [
	  "sudo yum -y install httpd && sudo systemctl start httpd",
	  "echo '<h1><center>My first website using terraform provisioner</center></h1' > index.html",
	  "echo '<h1><center>Coalfire</center></h1' >> index.html",
	  "sudo mv index.html /var/www/html/"
        ]

connection {
	type            = "ssh"
	host            = azurerm_public_ip.apache_terraform_pip.fqdn
	user            = var.admin_username
	private_key     = file("~/.ssh/id_rsa")
	}
}

resource "azurerm_network_security_group" "nsg" {
	name                = "nsg-${count.index + 1}"
	location            = azurerm_resource_group.rg.location
	resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "nsr' {
	name = "network-security-rule"
	priority = 100
	direction = "Inbound"
	access = "Allow"
	protocol = "ssh"
	source_port_range = "*"
	destination_port_range = "80"
	source_address_prefix = "*"
	destination_address_prefix = "10.0.2.0/24"
	resource_group_name = azurerm_resource_group.rg.name
	network_security_group__name = azurerm_network_security_group.nsg.name
}

resource "azurerm_subnet_network_security_group_association" "example" {
	subnet_id = azurerm.subnet.id
	network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_lb" "loadbalancer" {
  name                = var.load_balancer_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_lb_probe" "my_lb_probe" {
  resource_group_name = azurerm_resource_group.my_resource_group.name
  loadbalancer_id     = azurerm_lb.loadbalancer.id
  name                = "test-probe"
  port                = 80
}

resource "azurerm_storage_account" "storage_account" {
	name   = "coalfirestorageaccount"
	resource_group_name = azurerm_resource_group.rg.name
	location = azurerm_resource_group.rg.location
	account_kind = "BlobStorage"
	account_tier = "Standard"
	account_replication_type = "LRS"
}

##create managed private endpoint

resource "azurerm_storage_account_managed_private_endpoint" "pep_storage_account" {
	name  = "coalfirepep"
	target_resource_id = azurerm_storage_account.storage_account.id
	subresource_name = "blob"
}
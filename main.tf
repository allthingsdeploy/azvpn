terraform {
  backend "azurerm" {
    resource_group_name  = "RGMXCFX"
    storage_account_name = "samxtfstatenllmgyw6f6b7u"
    container_name       = "tfstate"
    key                  = "azvpn.tfstate"
    use_azuread_auth     = true
  }
}
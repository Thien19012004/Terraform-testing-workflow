output "public_ip_address" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "ssh_command" {
  description = "SSH command for connecting to the VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = azurerm_key_vault.vm.vault_uri
}

output "admin_password_secret_id" {
  description = "Key Vault secret ID for the VM admin password. Retrieve with: az keyvault secret show --id <value> --query value -o tsv"
  value       = azurerm_key_vault_secret.admin_password.id
}

output "public_ip_address" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "ssh_command" {
  description = "SSH command for connecting to the VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

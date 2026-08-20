variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use ARM_SUBSCRIPTION_ID or Azure CLI context."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for the VM."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-terraform-vm"
}

variable "vm_name" {
  description = "Name of the virtual machine."
  type        = string
  default     = "vm-terraform-linux"
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Contents of the SSH public key used to access the VM."
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Password for the Linux administrator. Must be 6-72 chars and contain at least 3 of: lowercase, uppercase, digit, special character."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 6 && length(var.admin_password) <= 72
    error_message = "admin_password must be between 6 and 72 characters."
  }
}

variable "allowed_ssh_source" {
  description = "CIDR allowed to connect over SSH. Replace the default with your public IP/CIDR."
  type        = string
  default     = "0.0.0.0/0"
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2ats_v2"
}

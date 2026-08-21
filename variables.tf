variable "fingerprint" {
  description = "Fingerprint of the API signing key uploaded for the OCI user."
  type        = string
}

variable "private_key_password" {
  description = "Passphrase for the private key file, if it is encrypted."
  type        = string
  sensitive   = true
  default     = null
}

variable "private_key_path" {
  description = "Path to the private key file used for API authentication."
  type        = string
}

variable "region" {
  description = "OCI region to target, e.g. us-ashburn-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user used for API authentication."
  type        = string
}

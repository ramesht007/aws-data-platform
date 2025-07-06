# =============================================================================
# Security Module Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# KMS Configuration
variable "kms_deletion_window" {
  description = "Number of days to retain KMS keys before deletion"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

# Security Group Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for ingress traffic"
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

# IAM Configuration
variable "cross_account_roles" {
  description = "List of cross-account roles to trust"
  type        = list(string)
  default     = []
}

variable "enable_mfa_requirement" {
  description = "Require MFA for sensitive operations"
  type        = bool
  default     = true
} 
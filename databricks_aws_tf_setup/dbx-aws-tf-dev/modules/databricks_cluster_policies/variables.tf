/**
 * Variables for Databricks Cluster Policies Module
 */

variable "workspace_name" {
  description = "Name of the Databricks workspace (used for policy naming)"
  type        = string
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cost_center" {
  description = "Cost center for tagging and chargeback"
  type        = string
  default     = "data-platform"
}

# ============================================================================
# DATA ENGINEERING POLICY INSTANCE TYPES
# ============================================================================

variable "allowed_instance_types" {
  description = "List of allowed EC2 instance types for data engineering clusters"
  type        = list(string)
  default = [
    "m5.large",   # 2 vCPU, 8 GB - General purpose, balanced
    "m5.xlarge",  # 4 vCPU, 16 GB
    "m5.2xlarge", # 8 vCPU, 32 GB
    "m5.4xlarge", # 16 vCPU, 64 GB
    "m5.8xlarge", # 32 vCPU, 128 GB
    "r5.large",   # 2 vCPU, 16 GB - Memory-optimized
    "r5.xlarge",  # 4 vCPU, 32 GB
    "r5.2xlarge", # 8 vCPU, 64 GB
    "r5.4xlarge", # 16 vCPU, 128 GB
    "c5.xlarge",  # 4 vCPU, 8 GB - Compute-optimized
    "c5.2xlarge", # 8 vCPU, 16 GB
    "c5.4xlarge", # 16 vCPU, 32 GB
    "i3.xlarge",  # 4 vCPU, 30.5 GB, 950 GB NVMe SSD - Storage-optimized
    "i3.2xlarge", # 8 vCPU, 61 GB, 1.9 TB NVMe SSD
    "i3.4xlarge"  # 16 vCPU, 122 GB, 3.8 TB NVMe SSD
  ]
}

variable "default_instance_type" {
  description = "Default EC2 instance type for data engineering clusters"
  type        = string
  default     = "m5.xlarge" # 4 vCPU, 16 GB - Good balance for most workloads
}

# ============================================================================
# ANALYST POLICY INSTANCE TYPES
# ============================================================================

variable "analyst_instance_types" {
  description = "List of allowed EC2 instance types for analyst clusters (smaller, cost-optimized)"
  type        = list(string)
  default = [
    "m5.large",   # 2 vCPU, 8 GB - General purpose
    "m5.xlarge",  # 4 vCPU, 16 GB
    "m5.2xlarge", # 8 vCPU, 32 GB
    "r5.large",   # 2 vCPU, 16 GB - Memory-optimized for SQL queries
    "r5.xlarge",  # 4 vCPU, 32 GB
    "c5.large",   # 2 vCPU, 4 GB - Compute-optimized
    "c5.xlarge"   # 4 vCPU, 8 GB
  ]
}

variable "analyst_default_instance_type" {
  description = "Default EC2 instance type for analyst clusters"
  type        = string
  default     = "m5.large" # 2 vCPU, 8 GB - Cost-effective for SQL queries
}

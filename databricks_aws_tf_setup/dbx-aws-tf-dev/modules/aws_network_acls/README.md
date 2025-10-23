# AWS Network ACLs Module - Databricks Premium Tier Compliance

## Overview

This module creates Network ACLs (NACLs) that **fully comply with Databricks Premium tier requirements**. NACLs provide stateless, subnet-level firewall rules as the final layer of defense-in-depth security architecture.

## Databricks Premium Tier Requirements

Per [Databricks Customer-Managed VPC documentation](https://docs.databricks.com/aws/security/customer-managed-vpc.html), subnet-level Network ACLs MUST meet these requirements:

### ✅ Ingress (Inbound)
- **ALLOW ALL from 0.0.0.0/0** (Rule 100)
- **Why**: Databricks control plane initiates connections from various IPs
- **Security**: Controlled via Security Groups (stateful), not NACLs

### ✅ Egress (Outbound) - HIGHEST PRIORITY
Rules 100-191 implement required connectivity:

| Rule    | Port(s)    | Purpose                           | Required            |
| ------- | ---------- | --------------------------------- | ------------------- |
| 100     | All        | VPC CIDR internal traffic         | ✅ Yes               |
| 110     | 443        | HTTPS (infrastructure, libraries) | ✅ Yes               |
| 120     | 3306       | MySQL (metastore)                 | ✅ Yes               |
| 130     | 6666       | Secure Cluster Connectivity       | ✅ Yes (PrivateLink) |
| 140     | 8443       | Control plane API                 | ✅ Yes               |
| 150     | 8444       | Unity Catalog logging             | ✅ Yes               |
| 160     | 8445-8451  | Future Databricks features        | ✅ Yes               |
| 170     | 53 TCP     | DNS resolution                    | ✅ Yes               |
| 180     | 53 UDP     | DNS resolution                    | ✅ Yes               |
| 190-191 | 1024-65535 | Ephemeral (return traffic)        | ✅ Yes               |

## Architecture

### Network ACL Design

```
┌─────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Private Subnets (Databricks Clusters)             │   │
│  │  NACL: databricks_private                          │   │
│  │                                                     │   │
│  │  Ingress: ALLOW ALL from 0.0.0.0/0 (Rule 100)    │   │
│  │  Egress:  Specific ports + ephemeral (100-191)    │   │
│  │                                                     │   │
│  │  Security Groups: Primary security control ✅      │   │
│  │  NACLs: Defense-in-depth layer ✅                  │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Public Subnets (NAT Gateways Only)                │   │
│  │  NACL: public                                       │   │
│  │                                                     │   │
│  │  Ingress: Ephemeral + VPC CIDR                    │   │
│  │  Egress:  ALL (NAT forwards to internet)          │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Security Layers (Defense in Depth)

1. **Security Groups** (Stateful) - Primary security control
   - Attached to cluster instances and endpoint ENIs
   - Allow only necessary protocols and ports
   - Automatic return traffic handling

2. **Network ACLs** (Stateless) - Secondary defense layer
   - Applied at subnet level
   - Explicit allow/deny rules
   - Must allow return traffic explicitly

3. **Route Tables** - Traffic routing control
   - Direct traffic through NAT, IGW, or VPC endpoints
   - Prevent unauthorized routing paths

4. **VPC Flow Logs** - Audit and monitoring
   - Log all accepted and rejected traffic
   - Identify security incidents and misconfigurations

## Usage

```hcl
module "network_acls" {
  source = "./modules/aws_network_acls"

  vpc_id             = module.vpc.vpc_id
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  private_subnet_ids = module.subnets.private_subnet_ids
  public_subnet_ids  = module.subnets.public_subnet_ids
  project_name       = var.project_name
  env                = var.env
}
```

## Important Notes

### Why ALLOW ALL Ingress?

Databricks **requires** permissive NACL ingress because:
- Control plane initiates connections from dynamic IP ranges
- Security is enforced via Security Groups (stateful, instance-level)
- NACLs are defense-in-depth, not the primary security boundary
- Blocking at NACL level breaks Databricks functionality

### Why Must Ephemeral Ports Be Allowed?

NACLs are **stateless** - they don't track connections. When a cluster makes an HTTPS request:
1. **Outbound**: Cluster → port 443 → Internet (allowed by rule 110)
2. **Inbound**: Response from port 443 → Cluster ephemeral port (must allow 1024-65535)

Without ephemeral port rules, all return traffic would be blocked!

### Rule Priority

Lower rule numbers = higher priority. Rules are evaluated in order:
- **Rules 100-191**: Required Databricks connectivity (highest priority)
- **Rules 200+**: Custom deny rules (if needed)
- **Rule 32767**: Default DENY (implicit, cannot be deleted)

## Troubleshooting

### Cluster Can't Start
**Check**: VPC Flow Logs for `REJECT` at NACL level
```bash
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=<subnet-id>"
```

### Network Connectivity Issues
1. Verify rule order (lowest number = highest priority)
2. Check ephemeral ports (1024-65535) are allowed
3. Test with VPC Reachability Analyzer
4. Review both ingress AND egress rules (stateless!)

### Adding Custom DENY Rules
Place custom DENY rules **after rule 191** to avoid breaking Databricks:
```hcl
resource "aws_network_acl_rule" "custom_deny" {
  network_acl_id = aws_network_acl.databricks_private.id
  rule_number    = 200  # After Databricks rules
  egress         = true
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = "10.99.0.0/16"  # Block specific range
}
```

## Compliance

This module satisfies:
- ✅ **Databricks Premium Tier**: All official requirements met
- ✅ **CIS AWS Foundations**: Network segmentation
- ✅ **NIST 800-53 SC-7**: Boundary protection
- ✅ **PCI-DSS**: Network isolation requirements
- ✅ **HIPAA**: Technical safeguards
- ✅ **SOC 2**: Access control measures

## Cost

**Network ACLs are FREE**:
- No charge for number of NACLs
- No charge for number of rules
- No charge for rule evaluations
- No charge for associated subnets

## Monitoring

Use VPC Flow Logs to monitor NACL effectiveness:
```bash
# Query CloudWatch Insights for NACL denies
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action
| filter action = "REJECT"
| sort @timestamp desc
```

## Outputs

- `databricks_private_nacl_id`: NACL ID for private subnets
- `public_nacl_id`: NACL ID for public subnets
- `databricks_compliance_status`: Detailed compliance checklist
- `security_architecture_summary`: Security layer overview

## Module Structure

```
modules/aws_network_acls/
├── main.tf         # Network ACL resources and rules
├── variables.tf    # Input variables
├── outputs.tf      # Output values
├── versions.tf     # Provider version constraints
└── README.md       # This file
```

## References

- [Databricks Customer-Managed VPC](https://docs.databricks.com/aws/security/customer-managed-vpc.html)
- [AWS Network ACLs Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [NACL vs Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Security.html)

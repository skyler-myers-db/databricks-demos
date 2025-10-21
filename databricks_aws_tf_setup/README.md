# Databricks on AWS First Time Setup Guide

## VPC Setup Information

### VPC Requirements

* The [VPC](https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#gsc.tab=0) must be in one of [these regions](https://docs.databricks.com/aws/en/resources/feature-region-support)
* Multiple workspaces can share the same VPC in the same AWS account
* Databricks recommends using unique subnets and security groups for each workspace
* Databricks assigns **two IP addresses per node**, one for management traffic and one for Apache Spark applications
* The total number of instances for each subnet is equal to half the number of IP addresses that are available
* The VPC must have DNS hostnames and DNS resolution enabled

### VPC IP Address Ranges

* Databricks doesn't limit netmasks for the workspace VPC
* Each workspace subnet must have a netmask between `/17` and `/26`
* This means that if your workspace has two subnets and both have a netmask of `/26`, then the netmask for your workspace VPC must be `/25` or smaller

### Subnets

* Databricks must have access to at least **two subnets for each workspace**, with each [subnet](https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#subnets) being in a different AZ
* You can share one or both subnets across multiple workspaces
* Subnets must be private
* Subnets must have outbound access to the public network using a NAT gateway and internet gateway, or other similar customer managed appliance infrastructure
* The NAT gateway must be set up in its own subnet that routes quad-zero (`0.0.0.0/0`) traffic to an internet gateway or other customer managed appliance infrastructure

### Security Groups

* A Databricks workspace must have access to at least one AWS security group and no more than five SGs
* You can reuse existing security groups, but Databricks recommends using **unique subnets and security groups for each workspace**

SGs must have the following rules:

#### Egress (outbound):

* Allow all TCP and UDP access to the workspace security group (for internal traffic)
* Allow TCP access to `0.0.0.0/0` for these ports:
    *  `443`: for Databricks infrastructure, cloud data sources, and library repositories
    *  `3306`: for the metastore
    *  `53`: for DNS resolution when you use custom DNS
    *  `6666`: for secure cluster connectivity. This is only required if you use PrivateLink
    *  `2443`: Supports FIPS encryption. Only required if you enable the compliance security profile
    *  `8443`: for internal calls from the Databricks compute plane to the Databricks control plane API
    *  `8444`: for Unity Catalog logging and lineage data streaming into Databricks
    *  `8445` through `8451`: Future extendability

#### Ingress (inbound): Required for all workspaces (these can be separate rules or combined into one):

* Allow TCP on all ports when traffic source uses the same security group
* Allow UDP on all ports when traffic source uses the same security group

**Note**: If you configure additional `ALLOW` or `DENY` rules for outbound traffic, set the rules required by Databricks to the highest priority (the lowest rule numbers), so that they take precedence

### Network ACLs

Don’t block traffic at the subnet NACL level. Databricks validates that NACLs do not deny ingress or egress; the guidance is effectively to allow all (or at least not deny the required ports) and control egress with a firewall/proxy if you need to restrict

Subnet level network ACLs must not deny ingress or egress to any traffic. Databricks validates for the following rules while creating the workspace:

#### Egress (outbound):

* Allow all traffic to the workspace VPC CIDR, for internal traffic
    * Allow TCP access to `0.0.0.0/0` for these ports:
        * `443`: for Databricks infrastructure, cloud data sources, and library repositories
        * `3306`: for the metastore
        * `6666`: only required if you use PrivateLink
        * `8443`: for internal calls from the Databricks compute plane to the Databricks control plane API
        * `8444`: for Unity Catalog logging and lineage data streaming into Databricks
        * `8445` through `8451`: Future extendability

#### Ingress (inbound):

* `ALLOW ALL` from Source `0.0.0.0/0`. This rule must be prioritized

### VPC Setup Guide

1. Go to AWS -> VPC -> Create VPC. Fill in like this (for [PrivateLink](https://docs.databricks.com/aws/en/security/network/classic/privatelink), use 3 private subnets) (make sure the subnet CIDRs are in the above range):

![image](https://docs.databricks.com/aws/en/assets/images/customer-managed-vpc-createnew-1a3dbddea152f6739db1b86c15d2b7e6.png)

#### Notes

* For public subnets, click 2. Those subnets aren't used directly by your Databricks workspace, but they are required to enable NATs in this editor
* Your Databricks workspace needs at least two private subnets. To resize them, click Customize subnet CIDR blocks
* The 2 private subnets should automatically attach to private route tables with the above specification `0.0.0.0/0` -> NAT Gateway

Confirm the following of your subnets:

* **Different AZs**: Each workspace must use exactly one subnet per AZ, and you need at least two AZs. Pick one subnet in `AZ‑1` and one in `AZ‑2` to be your workspace subnets.  ￼
* **CIDR sizes**: Each workspace subnet’s netmask must be `/17` to `/26`. If you used the VPC wizard’s “Customize subnet CIDR blocks,” you likely set this already (if your VPC uses secondary CIDR blocks, ensure the workspace subnets are from the same VPC CIDR block)  ￼
* **“Private” really means no direct IGW route / no public IPs**: Ensure the subnets do not have a `0.0.0.0/0` route to an Internet Gateway, and disable auto assign public IPv4 on those subnets (AWS best practice for private subnets). Databricks explicitly requires the subnets to be private

#### Route Table Associations

Make sure each private subnet is associated to a route table whose default route goes to a NAT (or your egress appliance/proxy), not to an IGW
* Route table entries should include:
* Local route for the VPC CIDR (auto)
* `0.0.0.0/0` → NAT Gateway (or your managed egress device)
* The Databricks requirement is that workspace subnet route tables must send quad‑zero traffic to a NAT (or equivalent)
* **Where is the NAT**? Put the NAT Gateway in a public subnet that has `0.0.0.0/0` → Internet Gateway; this should be default (that public subnet is not used by the workspace; it just hosts the NAT)
* Make sure the S3 Gateway is associated with the private route tables

#### Network ACLs (NACLs)

* Don’t block traffic at the subnet NACL level. Databricks validates that NACLs do not deny ingress or egress; the guidance is effectively to allow all (or at least not deny the required ports) and control egress with a firewall/proxy if you need to restrict

---

* Create a new security group with the above rules
    * You can modify the new SG to point to itself after creation
    * Use a dedicated SG for the workspace. Required egress includes TCP `443` (control plane, data sources), `3306` (metastore if used), `53` (DNS if using custom DNS), `8443`/`8444` (control plane APIs and lineage), and `6666` (only if using PrivateLink), with intra‑SG allow for TCP/UDP
* Update the Network ACL that was created to follow the above rules

### Configure Regional Endpoints

Databricks recommends you configure your VPC to use only regional VPC endpoints to AWS services. Using regional VPC endpoints enables more direct connections to AWS services and reduced cost compared to AWS global endpoints. There are four AWS services that a Databricks workspace with a customer managed VPC must reach: STS, S3, Kinesis, and RDS

* **S3 Gateway Endpoint**: You should already have the [S3 gateway endpoint](https://aws.amazon.com/blogs/aws/new-vpc-endpoint-for-amazon-s3)
* **STS Interface Endpoint**: Create this [endpoint](https://docs.aws.amazon.com/vpc/latest/userguide/vpce-interface.html#create-interface-endpoint) in your workspace private subnets and with the same SG for your workspace VPC (`com.amazonaws.<region>.sts`)
* **Kinesis Interface Endpoint**: Same as above, `com.amazonaws.<region>.kinesis-streams`
* **RDS Interface Endpoint**: Same as above, `com.amazonaws.<region>.rds`

### Configure Firewall Settings

For a firewall guide, follow [these instructions](https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc#configure-a-firewall-and-outbound-access)

### Restrict S3 Access

To restrict S3 access, follow [these instructions](https://docs.databricks.com/aws/en/security/network/classic/customer-managed-vpc?language=Python#optional-restrict-access-to-s3-buckets)

## Create Databricks Network Configuration

Follow [these](https://docs.databricks.com/aws/en/admin/account-settings-e2/networks#gsc.tab=0) steps

Follow the PrivateLink step here if needed

## Create a Storage Configuration, IAM Role With Custom Trust Policy, and IAM Policy for Read/Write

Follow [these](https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#create-a-storage-configuration) instructions

* After those steps, go to Databricks account console -> Cloud resources -> Storage configuration -> Add storage configuration
* Fill out and click "Add"

## Create Credential Configuration

Follow [these](https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#create-a-credential-configuration) steps

* After following and getting the policy ARN, go back to the Databricks account console -> Cloud resources -> Add credential configuration

## Advanced Configurations

### PrivateLink

Add a [private access setting](https://docs.databricks.com/aws/en/security/network/classic/private-access-settings)

### Customer Managed Keys

To configure customer managed keys, follow [these](https://docs.databricks.com/aws/en/security/keys/configure-customer-managed-keys) instructions

## Create a Metastore

Follow [these](https://docs.databricks.com/aws/en/data-governance/unity-catalog/create-metastore#step-3-create-the-metastore-and-attach-a-workspace) instructions

## Create a Workspace

Follow [these](https://docs.databricks.com/aws/en/admin/workspace/create-uc-workspace#create-a-workspace-with-custom-aws-configurations-1) instructions

## Extras

Full Databricks networking guide [here](https://docs.databricks.com/aws/en/security/network/#gsc.tab=0)

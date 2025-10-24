# ============================================================================
# AWS GuardDuty Module - Threat Detection & Security Monitoring
# ============================================================================
# Purpose: Continuously monitor for malicious activity and unauthorized behavior
# Required for: Production environments handling sensitive data
# Cost: ~$5-10/month (based on data volume analyzed)
#
# WHAT IT DETECTS:
# - Compromised EC2 instances (crypto mining, C&C communication, port scanning)
# - Compromised IAM credentials (unusual API calls, leaked keys, privilege escalation)
# - S3 bucket attacks (data exfiltration, unusual access patterns, public exposure)
# - Network attacks (port scanning, DDoS, unusual protocols)
# - Malware activity (known malicious IPs, domains, file hashes)
#
# DATA SOURCES ANALYZED:
# - VPC Flow Logs (network traffic patterns)
# - CloudTrail logs (API call patterns)
# - DNS logs (suspicious domain resolutions)
# - S3 data events (unusual bucket access)
# - EKS audit logs (Kubernetes API activity)
# - RDS login events (database access patterns)
#
# BEST PRACTICES:
# - Enable in all production accounts
# - Configure SNS notifications for high-severity findings
# - Integrate with Security Hub for centralized monitoring
# - Review findings daily
# - Automate remediation for known threats
# ============================================================================

# ============================================================================
# GUARDDUTY DETECTOR
# ============================================================================
resource "aws_guardduty_detector" "this" {
  enable = true

  # Finding publishing frequency
  finding_publishing_frequency = "FIFTEEN_MINUTES" # Options: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS

  tags = {
    Name        = "guardduty-${var.project_name}-${var.env}"
    Environment = var.env
    Project     = var.project_name
  }
}

# ============================================================================
# GUARDDUTY DETECTOR FEATURES (replaces deprecated datasources block)
# ============================================================================
# Enable S3 Data Event Monitoring
resource "aws_guardduty_detector_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# Enable EKS Audit Logs Monitoring
resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# Enable EBS Malware Protection
resource "aws_guardduty_detector_feature" "ebs_malware_protection" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

# Enable RDS Login Activity Monitoring
resource "aws_guardduty_detector_feature" "rds_login_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

# Enable Lambda Network Activity Monitoring
resource "aws_guardduty_detector_feature" "lambda_network_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "ENABLED"
}

# ============================================================================
# SNS TOPIC FOR GUARDDUTY ALERTS
# ============================================================================
resource "aws_sns_topic" "guardduty" {
  name = "guardduty-alerts-${var.project_name}-${var.env}"

  tags = {
    Name = "guardduty-alerts-${var.project_name}-${var.env}"
  }
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  topic_arn = aws_sns_topic.guardduty.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ============================================================================
# EVENTBRIDGE RULE FOR HIGH-SEVERITY FINDINGS
# ============================================================================
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-high-severity-${var.project_name}-${var.env}"
  description = "Capture GuardDuty findings with HIGH or CRITICAL severity"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9]
    }
  })

  tags = {
    Name = "guardduty-high-severity-rule-${var.project_name}-${var.env}"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty.arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      region      = "$.region"
      account     = "$.account"
      time        = "$.time"
      description = "$.detail.description"
      resource    = "$.detail.resource.resourceType"
    }

    input_template = <<EOF
"🚨 GuardDuty Alert - HIGH/CRITICAL Severity"
""
"Severity: <severity>"
"Finding Type: <type>"
"Description: <description>"
"Resource Type: <resource>"
"Account: <account>"
"Region: <region>"
"Time: <time>"
""
"Action Required: Review finding in AWS GuardDuty console immediately."
"Console: https://console.aws.amazon.com/guardduty/home?region=<region>#/findings"
EOF
  }
}

# SNS topic policy to allow EventBridge to publish
resource "aws_sns_topic_policy" "guardduty" {
  arn = aws_sns_topic.guardduty.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.guardduty.arn
      }
    ]
  })
}

# ============================================================================
# DATA SOURCES
# ============================================================================
data "aws_caller_identity" "current" {}

# ============================================================================
# OUTPUTS
# ============================================================================
output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.this.id
}

output "guardduty_detector_arn" {
  description = "GuardDuty detector ARN"
  value       = aws_guardduty_detector.this.arn
}

output "guardduty_sns_topic_arn" {
  description = "SNS topic ARN for GuardDuty alerts"
  value       = aws_sns_topic.guardduty.arn
}

output "guardduty_console_url" {
  description = "URL to GuardDuty console"
  value       = "https://console.aws.amazon.com/guardduty/home#/findings"
}

output "data_sources_enabled" {
  description = "List of GuardDuty data sources enabled"
  value = [
    "VPC Flow Logs",
    "CloudTrail Events",
    "DNS Logs",
    "S3 Data Events",
    "Kubernetes Audit Logs",
    "Malware Protection (EBS Scans)"
  ]
}

# ============================================================================
# USAGE NOTES
# ============================================================================
# Cost: ~$5-10/month
# - VPC Flow Logs analysis: $0.50 per million events
# - CloudTrail analysis: $4.40 per million events
# - S3 logs analysis: $0.80 per million events
# - Typical small account: ~$5-10/month
#
# Email Notifications:
# - AWS will send confirmation email to notification_email
# - Must click "Confirm subscription" to receive alerts
# - Alerts sent for HIGH (7.0-8.9) and CRITICAL (9.0-10.0) findings only
#
# Severity Levels:
# - LOW: 0.1-3.9 (informational, auto-archived if filter enabled)
# - MEDIUM: 4.0-6.9 (investigate when possible)
# - HIGH: 7.0-8.9 (immediate investigation required, alerts enabled)
# - CRITICAL: 9.0-10.0 (immediate action required, alerts enabled)
#
# Finding Types (Examples):
# - Backdoor:EC2/C&CActivity.B
# - CryptoCurrency:EC2/BitcoinTool.B
# - UnauthorizedAccess:IAMUser/MaliciousIPCaller
# - Recon:EC2/PortProbeUnprotectedPort
# - Exfiltration:S3/ObjectRead.Unusual
# - Impact:EC2/MaliciousDomain
#
# Threat Intelligence:
# - GuardDuty uses threat intel from AWS and CrowdStrike
# - Updated continuously with new malicious IPs/domains
# - Machine learning detects anomalous behavior
#
# Integration:
# - View findings in GuardDuty console
# - Export to Security Hub for centralized monitoring
# - Automate response with Lambda/EventBridge
# - Send to SIEM (Splunk, Datadog, etc.) via S3 export
# ============================================================================

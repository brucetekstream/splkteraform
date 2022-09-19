resource "aws_wafv2_ip_set" "ip_set" {
    name    = "Allowed_IP"
    description     = "IP addresses/ranges allowed to bypass WAF rules."
    scope           = "REGIONAL"
    ip_address_version = "IPV4"
    addresses = var.waf_allowed_cidrs
    tags = local.common_tags
}

resource "aws_wafv2_web_acl" "waf" {
    name = "${local.name_prefix}-waf-splunk"
    scope = "REGIONAL"
    default_action {
        allow {}
    }

    rule { 
        name     = "Block-Single-Factor" 
        priority = 0 

        action {
             block {}
        }
        statement {
            byte_match_statement {
                positional_constraint = "CONTAINS" 
                search_string         = "type=splunk"
                field_to_match {
                    query_string {}
                }
                text_transformation {
                    priority = 0
                    type     = "LOWERCASE" 
                }
            }
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                = "${local.name_prefix}-waf-splunk-block-single"
             sampled_requests_enabled   = true
        }
    }

    rule {
        name     = "Allow-IP-Set" 
        priority = 1

        action {
             allow {}
        }
        statement {
            ip_set_reference_statement {
                arn = aws_wafv2_ip_set.ip_set.arn
            }
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                = "${local.name_prefix}-waf-splunk-allow-ip"
            sampled_requests_enabled   = true
        }
    }

    rule { 
        name     = "AWS-AWSManagedRulesAnonymousIpList" 
        priority = 2

        statement {
            managed_rule_group_statement {
              vendor_name = "AWS"
              name = "AWSManagedRulesAnonymousIpList"
            }
        }
        override_action {
          none {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                = "AWS-AWSManagedRulesAnonymousIpList"
             sampled_requests_enabled   = true
        }
    }

    rule { 
        name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet" 
        priority = 3

        override_action {
          none {}
        }
        statement {
            managed_rule_group_statement {
              vendor_name = "AWS"
              name = "AWSManagedRulesKnownBadInputsRuleSet"
            }
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
             sampled_requests_enabled   = true
        }
    }



    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-waf-splunk"
      sampled_requests_enabled   = true
    }
}
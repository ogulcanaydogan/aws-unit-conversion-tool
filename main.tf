provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

# S3 Bucket for Static Website Hosting
resource "aws_s3_bucket" "unit_converter" {
  bucket = "convert.ogulcanaydogan.com"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_s3_bucket_policy" "unit_converter_policy" {
  bucket = aws_s3_bucket.unit_converter.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::convert.ogulcanaydogan.com/*"
    }
  ]
}
POLICY
}

# CloudFront Distribution for HTTPS
resource "aws_cloudfront_distribution" "unit_converter" {
  origin {
    domain_name = aws_s3_bucket.unit_converter.website_endpoint
    origin_id   = "S3-Origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "S3-Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "YOUR_ACM_CERTIFICATE_ARN" # Replace with your ACM Certificate ARN
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}

# Route 53 DNS Record for Custom Domain
resource "aws_route53_record" "unit_converter_dns" {
  zone_id = "YOUR_ROUTE53_ZONE_ID" # Replace with your hosted zone ID
  name    = "convert.ogulcanaydogan.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.unit_converter.domain_name
    zone_id                = aws_cloudfront_distribution.unit_converter.hosted_zone_id
    evaluate_target_health = false
  }
}

output "s3_website_url" {
  value = aws_s3_bucket.unit_converter.website_endpoint
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.unit_converter.domain_name
}

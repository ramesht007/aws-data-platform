# Storage Module

This module creates the foundational storage infrastructure for the AWS Serverless Data Platform, including S3 buckets for different data lake layers with appropriate security, lifecycle, and monitoring configurations.

## Architecture

The module creates a three-tier data lake architecture:

- **Raw Layer**: Ingests data in its original format
- **Processed Layer**: Stores transformed and cleaned data
- **Curated Layer**: Contains business-ready, aggregated data

## Resources Created

### S3 Buckets
- Raw data bucket with lifecycle policies
- Processed data bucket with lifecycle policies  
- Curated data bucket with extended retention
- Bucket versioning and encryption
- Public access blocking
- EventBridge notifications

### Security
- KMS key for S3 encryption
- KMS key alias for easier reference
- Bucket policies for least privilege access

### Lifecycle Management
- Intelligent tiering to optimize costs
- Automatic transition to IA, Glacier, and Deep Archive
- Configurable retention periods
- Noncurrent version cleanup

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  environment = "dev"
  region      = "us-east-1"
  account_id  = "123456789012"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  raw_bucket_name       = "my-company-raw"
  processed_bucket_name = "my-company-processed"
  curated_bucket_name   = "my-company-curated"

  storage = {
    s3 = {
      versioning          = true
      encryption          = "aws:kms"
      public_access_block = true
      force_destroy       = false
    }
    lifecycle = {
      transition_ia_days           = 30
      transition_glacier_days      = 90
      transition_deep_archive_days = 365
      expiration_days              = 2555
    }
  }

  security = {
    kms = {
      deletion_window     = 30
      enable_key_rotation = true
    }
  }

  common_tags = {
    Project     = "data-platform"
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| region | AWS region | `string` | n/a | yes |
| account_id | AWS account ID | `string` | n/a | yes |
| vpc_id | VPC ID for VPC endpoints | `string` | n/a | yes |
| private_subnet_ids | Private subnet IDs | `list(string)` | n/a | yes |
| raw_bucket_name | Raw bucket base name | `string` | `"aws-data-platform-raw"` | no |
| processed_bucket_name | Processed bucket base name | `string` | `"aws-data-platform-processed"` | no |
| curated_bucket_name | Curated bucket base name | `string` | `"aws-data-platform-curated"` | no |
| storage | Storage configuration | `object` | n/a | yes |
| security | Security configuration | `object` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| raw_bucket_id | Raw data bucket ID |
| processed_bucket_id | Processed data bucket ID |
| curated_bucket_id | Curated data bucket ID |
| s3_kms_key_arn | S3 KMS key ARN |
| all_bucket_arns | All bucket ARNs |
| storage_summary | Storage configuration summary |

## Data Lake Best Practices

### Raw Layer
- Store data in original format
- Partition by ingestion date
- Compress data when possible
- Use appropriate file formats (Parquet, ORC)

### Processed Layer
- Apply schema validation
- Clean and standardize data
- Remove PII if required
- Optimize for query performance

### Curated Layer
- Business-ready datasets
- Aggregated and summarized data
- Well-documented schemas
- Optimized for analytics workloads

## Cost Optimization

The module implements several cost optimization strategies:

1. **Intelligent Tiering**: Automatic movement to cheaper storage classes
2. **Lifecycle Policies**: Automated cleanup of old data
3. **Compression**: Reduced storage costs
4. **KMS Bucket Keys**: Reduced KMS costs for encryption

## Security Features

- **Encryption at Rest**: KMS encryption for all buckets
- **Public Access Blocking**: Prevents accidental public exposure
- **Versioning**: Protects against accidental deletion
- **Access Logging**: Audit trail for compliance
- **EventBridge Integration**: Real-time event processing 
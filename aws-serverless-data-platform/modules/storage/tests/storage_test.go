// =============================================================================
// Storage Module Test
// Tests the storage module infrastructure
// =============================================================================

package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TestStorage tests the storage module
func TestStorage(t *testing.T) {
	t.Parallel()

	// AWS region for testing
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"environment":  "test",
			"project_name": "dl-test",
			"region":       awsRegion,
			"account_id":   "356240508702",
			"storage": map[string]interface{}{
				"s3": map[string]interface{}{
					"versioning":          true,
					"encryption":          "AES256",
					"public_access_block": true,
					"force_destroy":       true,
				},
				"lifecycle": map[string]interface{}{
					"transition_ia_days":           90,
					"transition_glacier_days":      210,
					"transition_deep_archive_days": 365,
					"expiration_days":              730,
				},
			},
			"security": map[string]interface{}{
				"kms": map[string]interface{}{
					"deletion_window":     30,
					"enable_key_rotation": true,
				},
			},
			"common_tags": map[string]interface{}{
				"Environment": "test",
				"Project":     "terratest",
				"Testing":     "true",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify terraform outputs exist - this ensures resources were created successfully
	terraform.Output(t, terraformOptions, "raw_bucket_id")
	terraform.Output(t, terraformOptions, "processed_bucket_id")
	terraform.Output(t, terraformOptions, "curated_bucket_id")

	// Verify security resources exist
	terraform.Output(t, terraformOptions, "s3_kms_key_id")
	terraform.Output(t, terraformOptions, "s3_kms_key_arn")
	terraform.Output(t, terraformOptions, "s3_kms_alias_arn")

	// Verify lifecycle configurations exist
	terraform.Output(t, terraformOptions, "raw_bucket_lifecycle_configuration")
	terraform.Output(t, terraformOptions, "processed_bucket_lifecycle_configuration")
	terraform.Output(t, terraformOptions, "curated_bucket_lifecycle_configuration")

	// Verify encryption configurations exist
	terraform.Output(t, terraformOptions, "raw_bucket_encryption")
	terraform.Output(t, terraformOptions, "processed_bucket_encryption")
	terraform.Output(t, terraformOptions, "curated_bucket_encryption")

	// Verify Glue database resources exist
	terraform.Output(t, terraformOptions, "raw_database_name")
	terraform.Output(t, terraformOptions, "processed_database_name")
	terraform.Output(t, terraformOptions, "curated_database_name")

	// Verify Glue role exists
	terraform.Output(t, terraformOptions, "glue_log_group_name")
	terraform.Output(t, terraformOptions, "glue_log_group_arn")
}

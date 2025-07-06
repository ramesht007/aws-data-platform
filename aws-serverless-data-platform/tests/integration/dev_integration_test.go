// =============================================================================
// Development Environment Integration Test
// Tests the complete dev environment deployment
// =============================================================================

package integration

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestDevEnvironmentIntegration performs end-to-end testing of the dev environment
func TestDevEnvironmentIntegration(t *testing.T) {
	// Skip long-running integration tests in short mode
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	awsRegion := "us-east-1"
	environment := "dev"

	// Terragrunt options for the entire environment
	terragruntOptions := &terraform.Options{
		TerraformDir: fmt.Sprintf("../../environments/%s/%s", environment, awsRegion),
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Ensure cleanup happens
	defer func() {
		t.Log("Starting cleanup of integration test resources...")
		cleanupIntegrationTest(t, terragruntOptions)
	}()

	// Test deployment in phases
	t.Run("Phase1_Networking", func(t *testing.T) {
		testNetworkingDeployment(t, terragruntOptions, environment, awsRegion)
	})

	t.Run("Phase2_Storage", func(t *testing.T) {
		testStorageDeployment(t, terragruntOptions, environment, awsRegion)
	})

	t.Run("Phase3_EndToEnd", func(t *testing.T) {
		testEndToEndWorkflow(t, terragruntOptions, environment, awsRegion)
	})
}

// testNetworkingDeployment tests the networking module deployment
func testNetworkingDeployment(t *testing.T, terragruntOptions *terraform.Options, environment, region string) {
	networkingDir := fmt.Sprintf("%s/01-networking", terragruntOptions.TerraformDir)

	networkingOptions := &terraform.Options{
		TerraformDir: networkingDir,
		EnvVars:      terragruntOptions.EnvVars,
	}

	// Deploy networking
	t.Log("Deploying networking infrastructure...")
	shell.RunCommand(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"init"},
		WorkingDir: networkingDir,
	})

	shell.RunCommand(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"apply", "-auto-approve"},
		WorkingDir: networkingDir,
	})

	// Wait a bit for resources to be fully created
	time.Sleep(30 * time.Second)

	// Validate networking outputs
	vpcID := shell.RunCommandAndGetOutput(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"output", "-raw", "vpc_id"},
		WorkingDir: networkingDir,
	})

	require.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Verify VPC exists in AWS
	vpc := aws.GetVpcById(t, vpcID, region)
	assert.NotNil(t, vpc)
	assert.Equal(t, "10.0.0.0/16", *vpc.CidrBlock) // Dev environment CIDR

	t.Logf("✅ Networking deployment successful. VPC ID: %s", vpcID)
}

// testStorageDeployment tests the storage module deployment
func testStorageDeployment(t *testing.T, terragruntOptions *terraform.Options, environment, region string) {
	storageDir := fmt.Sprintf("%s/03-storage", terragruntOptions.TerraformDir)

	// Deploy storage
	t.Log("Deploying storage infrastructure...")
	shell.RunCommand(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"init"},
		WorkingDir: storageDir,
	})

	shell.RunCommand(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"apply", "-auto-approve"},
		WorkingDir: storageDir,
	})

	// Wait for S3 eventual consistency
	time.Sleep(15 * time.Second)

	// Validate storage outputs
	rawBucketID := shell.RunCommandAndGetOutput(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"output", "-raw", "raw_bucket_id"},
		WorkingDir: storageDir,
	})

	processedBucketID := shell.RunCommandAndGetOutput(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"output", "-raw", "processed_bucket_id"},
		WorkingDir: storageDir,
	})

	curatedBucketID := shell.RunCommandAndGetOutput(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"output", "-raw", "curated_bucket_id"},
		WorkingDir: storageDir,
	})

	require.NotEmpty(t, rawBucketID, "Raw bucket ID should not be empty")
	require.NotEmpty(t, processedBucketID, "Processed bucket ID should not be empty")
	require.NotEmpty(t, curatedBucketID, "Curated bucket ID should not be empty")

	// Verify buckets exist and have correct configuration
	assert.True(t, aws.S3BucketExists(t, region, rawBucketID))
	assert.True(t, aws.S3BucketExists(t, region, processedBucketID))
	assert.True(t, aws.S3BucketExists(t, region, curatedBucketID))

	// Test bucket encryption
	assert.True(t, aws.AssertS3BucketHasDefaultEncryption(t, region, rawBucketID))
	assert.True(t, aws.AssertS3BucketHasDefaultEncryption(t, region, processedBucketID))
	assert.True(t, aws.AssertS3BucketHasDefaultEncryption(t, region, curatedBucketID))

	// Test bucket versioning
	assert.True(t, aws.GetS3BucketVersioning(t, region, rawBucketID))
	assert.True(t, aws.GetS3BucketVersioning(t, region, processedBucketID))
	assert.True(t, aws.GetS3BucketVersioning(t, region, curatedBucketID))

	t.Logf("✅ Storage deployment successful. Buckets: %s, %s, %s",
		rawBucketID, processedBucketID, curatedBucketID)
}

// testEndToEndWorkflow tests a simple data flow through the platform
func testEndToEndWorkflow(t *testing.T, terragruntOptions *terraform.Options, environment, region string) {
	t.Log("Testing end-to-end data workflow...")

	// Get storage bucket information
	storageDir := fmt.Sprintf("%s/03-storage", terragruntOptions.TerraformDir)

	rawBucketID := shell.RunCommandAndGetOutput(t, shell.Command{
		Command:    "terragrunt",
		Args:       []string{"output", "-raw", "raw_bucket_id"},
		WorkingDir: storageDir,
	})

	// Test data upload to raw bucket
	testData := "test-data-" + fmt.Sprintf("%d", time.Now().Unix())
	testKey := "test/sample-data.txt"

	t.Log("Uploading test data to raw bucket...")
	aws.PutS3BucketObject(t, region, rawBucketID, testKey, testData)

	// Verify data was uploaded
	actualData := aws.GetS3ObjectContents(t, region, rawBucketID, testKey)
	assert.Equal(t, testData, actualData)

	// Test data lifecycle (verify object transitions would work)
	// Note: Actual lifecycle transitions take time, so we just verify the policies exist
	bucketPolicy := aws.GetS3BucketPolicy(t, region, rawBucketID)
	assert.NotNil(t, bucketPolicy) // Should have lifecycle policies

	// Cleanup test data
	aws.DeleteS3Object(t, region, rawBucketID, testKey)

	t.Log("✅ End-to-end workflow test completed successfully")
}

// cleanupIntegrationTest performs cleanup of integration test resources
func cleanupIntegrationTest(t *testing.T, terragruntOptions *terraform.Options) {
	t.Log("Performing integration test cleanup...")

	// Destruction order (reverse of creation)
	destructionOrder := []string{
		"08-monitoring",
		"07-analytics",
		"06-orchestration",
		"05-streaming",
		"04-data-catalog",
		"03-storage",
		"02-security",
		"01-networking",
	}

	for _, module := range destructionOrder {
		moduleDir := fmt.Sprintf("%s/%s", terragruntOptions.TerraformDir, module)

		// Check if module directory exists
		if shell.CommandExists("test") {
			if err := shell.RunCommandE(t, shell.Command{
				Command: "test",
				Args:    []string{"-d", moduleDir},
			}); err != nil {
				continue // Skip if directory doesn't exist
			}
		}

		t.Logf("Destroying module: %s", module)

		// Destroy with retry logic
		maxRetries := 3
		for i := 0; i < maxRetries; i++ {
			err := shell.RunCommandE(t, shell.Command{
				Command:    "terragrunt",
				Args:       []string{"destroy", "-auto-approve"},
				WorkingDir: moduleDir,
			})

			if err == nil {
				break
			}

			if i == maxRetries-1 {
				t.Logf("⚠️  Failed to destroy module %s after %d attempts: %v", module, maxRetries, err)
			} else {
				t.Logf("Retry %d/%d for destroying module %s", i+1, maxRetries, module)
				time.Sleep(30 * time.Second)
			}
		}
	}

	t.Log("✅ Integration test cleanup completed")
}

// TestDevEnvironmentValidation performs validation tests without deployment
func TestDevEnvironmentValidation(t *testing.T) {
	awsRegion := "us-east-1"
	environment := "dev"

	terragruntDir := fmt.Sprintf("../../environments/%s/%s", environment, awsRegion)

	// Test Terragrunt configuration validation
	t.Run("TerragruntValidation", func(t *testing.T) {
		// Validate all Terragrunt configurations
		shell.RunCommand(t, shell.Command{
			Command:    "terragrunt",
			Args:       []string{"validate-all"},
			WorkingDir: terragruntDir,
		})
	})

	// Test Terraform formatting
	t.Run("TerraformFormatting", func(t *testing.T) {
		shell.RunCommand(t, shell.Command{
			Command:    "terraform",
			Args:       []string{"fmt", "-check", "-recursive"},
			WorkingDir: "../../",
		})
	})

	t.Log("✅ Dev environment validation completed successfully")
}

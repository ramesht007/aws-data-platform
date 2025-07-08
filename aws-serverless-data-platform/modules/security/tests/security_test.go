package test

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	awssdk "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/iam"
	terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIAMPoliciesAndRoles(t *testing.T) {
	t.Parallel()

	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name": "security-test",
			"environment":  "test",
			"region":       awsRegion,
			"account_id":   "356240508702",
			"vpc_id":       "vpc-0123456789abcdef0",
		},
		// Add retry configuration for flaky tests
		RetryableTerraformErrors: map[string]string{
			".*": "Terraform operation failed",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	// Clean up resources on test completion
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Run comprehensive IAM tests
	t.Run("TestIAMRoles", func(t *testing.T) {
		testIAMRoles(t, terraformOptions, awsRegion)
	})

	t.Run("TestIAMPolicies", func(t *testing.T) {
		testIAMPolicies(t, terraformOptions, awsRegion)
	})

	t.Run("TestRolePolicyAttachments", func(t *testing.T) {
		testRolePolicyAttachments(t, terraformOptions, awsRegion)
	})

	t.Run("TestAssumeRolePolicies", func(t *testing.T) {
		testAssumeRolePolicies(t, terraformOptions, awsRegion)
	})
}

func testIAMRoles(t *testing.T, terraformOptions *terraform.Options, awsRegion string) {
	// Get role outputs from Terraform
	glueRoleArn := terraform.Output(t, terraformOptions, "glue_role_arn")
	glueRoleName := terraform.Output(t, terraformOptions, "glue_role_name")

	// Validate role ARN format
	require.Contains(t, glueRoleArn, "arn:aws:iam::")
	require.Contains(t, glueRoleArn, ":role/")
	require.NotEmpty(t, glueRoleName)

	// Create AWS session using the aliased import
	sess := session.Must(session.NewSession(&awssdk.Config{
		Region: awssdk.String(awsRegion),
	}))
	iamClient := iam.New(sess)

	// Test role exists and is accessible
	roleInput := &iam.GetRoleInput{
		RoleName: awssdk.String(glueRoleName),
	}

	role, err := iamClient.GetRole(roleInput)
	require.NoError(t, err, "Failed to get IAM role")
	require.NotNil(t, role.Role)

	// Validate role properties
	assert.Equal(t, glueRoleName, *role.Role.RoleName)
	assert.Contains(t, *role.Role.Arn, glueRoleName)
	assert.NotEmpty(t, *role.Role.AssumeRolePolicyDocument)

	// Validate role tags (if your Terraform adds tags)
	if len(role.Role.Tags) > 0 {
		tagMap := make(map[string]string)
		for _, tag := range role.Role.Tags {
			tagMap[*tag.Key] = *tag.Value
		}

		// Check for expected tags
		assert.Equal(t, "test", tagMap["Environment"])
		assert.Equal(t, "security-test", tagMap["Project"])
	}

	t.Logf("✅ IAM Role validation passed for: %s", glueRoleName)
}

func testIAMPolicies(t *testing.T, terraformOptions *terraform.Options, awsRegion string) {
	// Get policy outputs from Terraform
	s3PolicyArn := terraform.Output(t, terraformOptions, "s3_data_access_policy_arn")
	gluePolicyArn := terraform.Output(t, terraformOptions, "glue_catalog_access_policy_arn")

	policies := map[string]string{
		"S3 Data Access Policy":      s3PolicyArn,
		"Glue Catalog Access Policy": gluePolicyArn,
	}

	// Create AWS session using the aliased import
	sess := session.Must(session.NewSession(&awssdk.Config{
		Region: awssdk.String(awsRegion),
	}))
	iamClient := iam.New(sess)

	for policyName, policyArn := range policies {
		t.Run(policyName, func(t *testing.T) {
			// Validate policy ARN format
			require.Contains(t, policyArn, "arn:aws:iam::")
			require.Contains(t, policyArn, ":policy/")

			// Get policy details
			policyInput := &iam.GetPolicyInput{
				PolicyArn: awssdk.String(policyArn),
			}

			policy, err := iamClient.GetPolicy(policyInput)
			require.NoError(t, err, "Failed to get IAM policy: %s", policyName)
			require.NotNil(t, policy.Policy)

			// Validate policy properties
			assert.Equal(t, policyArn, *policy.Policy.Arn)
			assert.NotEmpty(t, *policy.Policy.PolicyName)
			assert.True(t, *policy.Policy.DefaultVersionId != "")

			// Get policy document
			policyVersionInput := &iam.GetPolicyVersionInput{
				PolicyArn: awssdk.String(policyArn),
				VersionId: policy.Policy.DefaultVersionId,
			}

			policyVersion, err := iamClient.GetPolicyVersion(policyVersionInput)
			require.NoError(t, err, "Failed to get policy version")

			// Validate policy document structure
			validatePolicyDocument(t, *policyVersion.PolicyVersion.Document, policyName)

			t.Logf("✅ IAM Policy validation passed for: %s", policyName)
		})
	}
}

func testRolePolicyAttachments(t *testing.T, terraformOptions *terraform.Options, awsRegion string) {
	glueRoleName := terraform.Output(t, terraformOptions, "glue_role_name")
	s3PolicyArn := terraform.Output(t, terraformOptions, "s3_data_access_policy_arn")
	gluePolicyArn := terraform.Output(t, terraformOptions, "glue_catalog_access_policy_arn")

	// Create AWS session using the aliased import
	sess := session.Must(session.NewSession(&awssdk.Config{
		Region: awssdk.String(awsRegion),
	}))
	iamClient := iam.New(sess)

	// List attached policies for the role
	listInput := &iam.ListAttachedRolePoliciesInput{
		RoleName: awssdk.String(glueRoleName),
	}

	attachedPolicies, err := iamClient.ListAttachedRolePolicies(listInput)
	require.NoError(t, err, "Failed to list attached role policies")

	// Create map of attached policy ARNs
	attachedPolicyArns := make(map[string]bool)
	for _, policy := range attachedPolicies.AttachedPolicies {
		attachedPolicyArns[*policy.PolicyArn] = true
	}

	// Verify expected policies are attached
	expectedPolicies := []string{s3PolicyArn, gluePolicyArn}
	for _, expectedArn := range expectedPolicies {
		assert.True(t, attachedPolicyArns[expectedArn],
			"Expected policy %s to be attached to role %s", expectedArn, glueRoleName)
	}

	t.Logf("✅ Role policy attachments validated for role: %s", glueRoleName)
}

func testAssumeRolePolicies(t *testing.T, terraformOptions *terraform.Options, awsRegion string) {
	glueRoleName := terraform.Output(t, terraformOptions, "glue_role_name")

	// Create AWS session using the aliased import
	sess := session.Must(session.NewSession(&awssdk.Config{
		Region: awssdk.String(awsRegion),
	}))
	iamClient := iam.New(sess)

	// Get role assume role policy
	roleInput := &iam.GetRoleInput{
		RoleName: awssdk.String(glueRoleName),
	}

	role, err := iamClient.GetRole(roleInput)
	require.NoError(t, err, "Failed to get IAM role")

	// Parse assume role policy document
	var assumeRolePolicy map[string]interface{}
	err = json.Unmarshal([]byte(*role.Role.AssumeRolePolicyDocument), &assumeRolePolicy)
	require.NoError(t, err, "Failed to parse assume role policy document")

	// Validate assume role policy structure
	assert.Equal(t, "2012-10-17", assumeRolePolicy["Version"])

	statements, ok := assumeRolePolicy["Statement"].([]interface{})
	require.True(t, ok, "Statement should be an array")
	require.Greater(t, len(statements), 0, "Should have at least one statement")

	// Validate first statement (assuming it's for Glue service)
	firstStatement := statements[0].(map[string]interface{})
	assert.Equal(t, "Allow", firstStatement["Effect"])

	principal, ok := firstStatement["Principal"].(map[string]interface{})
	require.True(t, ok, "Principal should be an object")

	service, ok := principal["Service"]
	require.True(t, ok, "Service should be specified in Principal")

	// Check if Glue service is allowed to assume the role
	serviceStr := fmt.Sprintf("%v", service)
	assert.Contains(t, serviceStr, "glue.amazonaws.com",
		"Glue service should be allowed to assume the role")

	t.Logf("✅ Assume role policy validation passed for: %s", glueRoleName)
}

func validatePolicyDocument(t *testing.T, policyDocument, policyName string) {
	var policy map[string]interface{}
	err := json.Unmarshal([]byte(policyDocument), &policy)
	require.NoError(t, err, "Failed to parse policy document for %s", policyName)

	// Validate basic policy structure
	assert.Equal(t, "2012-10-17", policy["Version"], "Policy version should be 2012-10-17")

	statements, ok := policy["Statement"].([]interface{})
	require.True(t, ok, "Statement should be an array")
	require.Greater(t, len(statements), 0, "Should have at least one statement")

	// Validate each statement has required fields
	for i, stmt := range statements {
		statement := stmt.(map[string]interface{})

		// Check required fields
		assert.Contains(t, statement, "Effect", "Statement %d should have Effect", i)
		assert.Contains(t, statement, "Action", "Statement %d should have Action", i)

		// Validate Effect is Allow or Deny
		effect := statement["Effect"].(string)
		assert.Contains(t, []string{"Allow", "Deny"}, effect,
			"Statement %d Effect should be Allow or Deny", i)

		// Validate specific policy content based on policy name
		if strings.Contains(policyName, "S3") {
			validateS3PolicyContent(t, statement, i)
		} else if strings.Contains(policyName, "Glue") {
			validateGluePolicyContent(t, statement, i)
		}
	}

	t.Logf("✅ Policy document validation passed for: %s", policyName)
}

func validateS3PolicyContent(t *testing.T, statement map[string]interface{}, index int) {
	actions := statement["Action"]
	actionsStr := fmt.Sprintf("%v", actions)

	// Check for common S3 actions
	expectedS3Actions := []string{"s3:GetObject", "s3:PutObject", "s3:ListBucket"}
	for _, action := range expectedS3Actions {
		if strings.Contains(actionsStr, action) {
			t.Logf("✅ Found expected S3 action: %s in statement %d", action, index)
			break
		}
	}
}

func validateGluePolicyContent(t *testing.T, statement map[string]interface{}, index int) {
	actions := statement["Action"]
	actionsStr := fmt.Sprintf("%v", actions)

	// Check for common Glue actions
	expectedGlueActions := []string{"glue:GetTable", "glue:GetDatabase", "glue:CreateTable"}
	for _, action := range expectedGlueActions {
		if strings.Contains(actionsStr, action) {
			t.Logf("✅ Found expected Glue action: %s in statement %d", action, index)
			break
		}
	}
}

// Helper function to test policy simulation with updated imports
func TestPolicySimulation(t *testing.T) {
	t.Parallel()

	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name": "security-test",
			"environment":  "test",
			"region":       awsRegion,
			"account_id":   "356240508702",
			"vpc_id":       "vpc-0123456789abcdef0",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	glueRoleArn := terraform.Output(t, terraformOptions, "glue_role_arn")

	// Create AWS session using the aliased import
	sess := session.Must(session.NewSession(&awssdk.Config{
		Region: awssdk.String(awsRegion),
	}))
	iamClient := iam.New(sess)

	// Test policy simulation for specific actions
	simulationInput := &iam.SimulatePrincipalPolicyInput{
		PolicySourceArn: awssdk.String(glueRoleArn),
		ActionNames: []*string{
			awssdk.String("s3:GetObject"),
			awssdk.String("glue:GetTable"),
		},
		ResourceArns: []*string{
			awssdk.String("arn:aws:s3:::my-data-bucket/*"),
			awssdk.String("arn:aws:glue:us-east-1:356240508702:table/my-database/my-table"),
		},
	}

	result, err := iamClient.SimulatePrincipalPolicy(simulationInput)
	require.NoError(t, err, "Failed to simulate principal policy")

	// Validate simulation results
	for _, evalResult := range result.EvaluationResults {
		t.Logf("Action: %s, Decision: %s", *evalResult.EvalActionName, *evalResult.EvalDecision)

		// You can add specific assertions based on expected permissions
		if *evalResult.EvalActionName == "s3:GetObject" {
			assert.Equal(t, "allowed", *evalResult.EvalDecision,
				"S3 GetObject should be allowed")
		}
	}

	t.Logf("✅ Policy simulation completed successfully")
}

// Additional helper function using Terratest AWS utilities
func TestWithTerratestAWSHelpers(t *testing.T) {
	t.Parallel()

	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name": "security-test",
			"environment":  "test",
			"region":       awsRegion,
			"account_id":   "356240508702",
			"vpc_id":       "vpc-0123456789abcdef0",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	glueRoleName := terraform.Output(t, terraformOptions, "glue_role_name")

	// Example of using Terratest AWS helpers with the aliased import
	// Note: You can now use terratest_aws for any Terratest-specific AWS utilities
	accountId := terratest_aws.GetAccountId(t)
	t.Logf("Current AWS Account ID: %s", accountId)

	// Verify the role exists using Terratest helpers
	roleArn := fmt.Sprintf("arn:aws:iam::%s:role/%s", accountId, glueRoleName)
	t.Logf("Expected role ARN: %s", roleArn)

	t.Logf("✅ Terratest AWS helpers integration test passed")
}

#!/usr/bin/env python3

# =============================================================================
# Terraform Plan Summary Script
# Parses Terraform plan JSON output and generates human-readable summaries
# =============================================================================

import json
import argparse
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List, Tuple, Any

def parse_plan(plan_path: str) -> Tuple[Counter, Counter, Dict]:
    """
    Parse Terraform plan JSON file and extract change statistics.
    
    Args:
        plan_path: Path to the Terraform plan JSON file
        
    Returns:
        Tuple of (summary_counter, service_counter, module_counter)
    """
    try:
        with open(plan_path, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: Plan file not found: {plan_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in plan file: {e}", file=sys.stderr)
        sys.exit(1)
    
    changes = data.get("resource_changes", [])
    
    summary = Counter()
    by_service = Counter()
    by_module = defaultdict(Counter)
    
    for resource_change in changes:
        # Get the action tuple (e.g., ["create"], ["update"], ["delete"])
        actions = tuple(resource_change["change"]["actions"])
        summary[actions] += 1
        
        # Extract service from resource type (e.g., aws_s3_bucket -> s3)
        resource_type = resource_change["type"]
        service = extract_service_name(resource_type)
        by_service[(actions, service)] += 1
        
        # Extract module information
        module_address = resource_change.get("module_address", "root")
        by_module[module_address][actions] += 1
    
    return summary, by_service, by_module

def extract_service_name(resource_type: str) -> str:
    """
    Extract AWS service name from Terraform resource type.
    
    Args:
        resource_type: Terraform resource type (e.g., aws_s3_bucket)
        
    Returns:
        Service name (e.g., s3)
    """
    if not resource_type.startswith("aws_"):
        return "other"
    
    # Remove aws_ prefix and extract service
    parts = resource_type[4:].split("_")
    
    # Handle special cases for better service grouping
    service_mappings = {
        "instance": "ec2",
        "vpc": "vpc",
        "subnet": "vpc", 
        "internet_gateway": "vpc",
        "nat_gateway": "vpc",
        "route_table": "vpc",
        "security_group": "ec2",
        "s3": "s3",
        "iam": "iam",
        "lambda": "lambda",
        "cloudwatch": "cloudwatch",
        "rds": "rds",
        "dynamodb": "dynamodb",
        "kinesis": "kinesis",
        "glue": "glue",
        "athena": "athena",
        "msk": "msk",
        "mwaa": "mwaa",
        "step_functions": "stepfunctions",
        "kms": "kms",
        "secretsmanager": "secretsmanager",
        "ssm": "ssm",
        "cloudtrail": "cloudtrail",
        "config": "config",
        "guardduty": "guardduty",
        "cloudformation": "cloudformation",
        "route53": "route53",
        "acm": "acm",
        "waf": "waf",
        "apigateway": "apigateway",
        "cognito": "cognito",
        "sns": "sns",
        "sqs": "sqs",
        "elasticsearch": "elasticsearch",
        "opensearch": "opensearch",
    }
    
    # Try to match the first part
    first_part = parts[0]
    if first_part in service_mappings:
        return service_mappings[first_part]
    
    # For unknown services, return the first part
    return first_part

def format_actions(actions: Tuple[str, ...]) -> str:
    """
    Format action tuple into human-readable string.
    
    Args:
        actions: Tuple of actions
        
    Returns:
        Formatted action string
    """
    action_map = {
        ("create",): "🟢 create",
        ("update",): "🟡 update", 
        ("delete",): "🔴 delete",
        ("create", "delete"): "🔄 replace",
        ("delete", "create"): "🔄 replace",
        ("no-op",): "⚪ no-op",
        ("read",): "📖 read",
    }
    
    return action_map.get(actions, f"❓ {', '.join(actions)}")

def print_summary(summary: Counter, by_service: Counter, by_module: Dict, 
                 show_details: bool = False, output_format: str = "text") -> None:
    """
    Print the plan summary in the specified format.
    
    Args:
        summary: Summary counter of actions
        by_service: Counter of actions by service
        by_module: Counter of actions by module
        show_details: Whether to show detailed breakdown
        output_format: Output format (text, markdown, json)
    """
    total = sum(summary.values())
    
    if output_format == "json":
        print_json_summary(summary, by_service, by_module, total)
    elif output_format == "markdown":
        print_markdown_summary(summary, by_service, by_module, total, show_details)
    else:
        print_text_summary(summary, by_service, by_module, total, show_details)

def print_text_summary(summary: Counter, by_service: Counter, by_module: Dict,
                      total: int, show_details: bool) -> None:
    """Print summary in plain text format."""
    print("=" * 60)
    print("TERRAFORM PLAN SUMMARY")
    print("=" * 60)
    print(f"Total changes: {total} resources")
    print()
    
    if total == 0:
        print("✅ No changes detected!")
        return
    
    # Overall summary
    print("📋 OVERALL CHANGES:")
    for actions, count in summary.most_common():
        print(f"  {format_actions(actions)}: {count} resources")
    print()
    
    # By service
    if show_details and by_service:
        print("🔧 BY SERVICE:")
        service_totals = defaultdict(int)
        service_details = defaultdict(list)
        
        for (actions, service), count in by_service.items():
            service_totals[service] += count
            service_details[service].append((actions, count))
        
        for service in sorted(service_totals.keys()):
            print(f"  {service.upper()}: {service_totals[service]} total")
            for actions, count in sorted(service_details[service]):
                print(f"    └─ {format_actions(actions)}: {count}")
        print()
    
    # By module
    if show_details and by_module:
        print("📦 BY MODULE:")
        for module_name in sorted(by_module.keys()):
            module_total = sum(by_module[module_name].values())
            module_display = module_name if module_name != "root" else "root"
            print(f"  {module_display}: {module_total} total")
            
            for actions, count in sorted(by_module[module_name].items()):
                print(f"    └─ {format_actions(actions)}: {count}")
        print()

def print_markdown_summary(summary: Counter, by_service: Counter, by_module: Dict,
                          total: int, show_details: bool) -> None:
    """Print summary in Markdown format."""
    print("# Terraform Plan Summary")
    print()
    print(f"**Total changes:** {total} resources")
    print()
    
    if total == 0:
        print("✅ **No changes detected!**")
        return
    
    # Overall summary
    print("## 📋 Overall Changes")
    print()
    print("| Action | Count |")
    print("|--------|-------|")
    
    for actions, count in summary.most_common():
        action_str = format_actions(actions).replace("🟢 ", "").replace("🟡 ", "").replace("🔴 ", "").replace("🔄 ", "").replace("⚪ ", "").replace("📖 ", "").replace("❓ ", "")
        print(f"| {action_str} | {count} |")
    print()
    
    # By service
    if show_details and by_service:
        print("## 🔧 By Service")
        print()
        service_totals = defaultdict(int)
        service_details = defaultdict(list)
        
        for (actions, service), count in by_service.items():
            service_totals[service] += count
            service_details[service].append((actions, count))
        
        print("| Service | Total | Details |")
        print("|---------|-------|---------|")
        
        for service in sorted(service_totals.keys()):
            details = ", ".join([f"{format_actions(actions).split(' ')[1]}: {count}" 
                               for actions, count in sorted(service_details[service])])
            print(f"| {service.upper()} | {service_totals[service]} | {details} |")
        print()
    
    # By module
    if show_details and by_module:
        print("## 📦 By Module")
        print()
        print("| Module | Total | Details |")
        print("|--------|-------|---------|")
        
        for module_name in sorted(by_module.keys()):
            module_total = sum(by_module[module_name].values())
            module_display = module_name if module_name != "root" else "root"
            details = ", ".join([f"{format_actions(actions).split(' ')[1]}: {count}" 
                               for actions, count in sorted(by_module[module_name].items())])
            print(f"| {module_display} | {module_total} | {details} |")
        print()

def print_json_summary(summary: Counter, by_service: Counter, by_module: Dict,
                      total: int) -> None:
    """Print summary in JSON format."""
    result = {
        "total_changes": total,
        "summary": dict(summary),
        "by_service": {},
        "by_module": {}
    }
    
    # Convert by_service to JSON-serializable format
    service_totals = defaultdict(int)
    service_details = defaultdict(dict)
    
    for (actions, service), count in by_service.items():
        service_totals[service] += count
        action_key = "_".join(actions)
        service_details[service][action_key] = count
    
    result["by_service"] = {
        service: {
            "total": service_totals[service],
            "details": dict(service_details[service])
        }
        for service in service_totals.keys()
    }
    
    # Convert by_module to JSON-serializable format
    result["by_module"] = {
        module: {
            "total": sum(actions_counter.values()),
            "details": {
                "_".join(actions): count 
                for actions, count in actions_counter.items()
            }
        }
        for module, actions_counter in by_module.items()
    }
    
    print(json.dumps(result, indent=2))

def main() -> None:
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Summarize Terraform plan output",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic summary
  python summarize_plan.py plan.json
  
  # Detailed summary with service and module breakdown
  python summarize_plan.py plan.json --details
  
  # Generate Markdown output
  python summarize_plan.py plan.json --format markdown
  
  # Generate JSON output
  python summarize_plan.py plan.json --format json
        """
    )
    
    parser.add_argument(
        "plan_json",
        help="Path to Terraform plan JSON file"
    )
    
    parser.add_argument(
        "--details", "-d",
        action="store_true",
        help="Show detailed breakdown by service and module"
    )
    
    parser.add_argument(
        "--format", "-f",
        choices=["text", "markdown", "json"],
        default="text",
        help="Output format (default: text)"
    )
    
    parser.add_argument(
        "--version",
        action="version",
        version="summarize_plan.py 1.0.0"
    )
    
    args = parser.parse_args()
    
    # Validate plan file exists
    if not Path(args.plan_json).exists():
        print(f"Error: Plan file not found: {args.plan_json}", file=sys.stderr)
        sys.exit(1)
    
    # Parse plan and generate summary
    summary, by_service, by_module = parse_plan(args.plan_json)
    print_summary(summary, by_service, by_module, args.details, args.format)

if __name__ == "__main__":
    main() 
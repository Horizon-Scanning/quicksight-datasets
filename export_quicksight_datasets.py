#!/usr/bin/env python3
"""
QuickSight Dataset Version Control Script
Exports all QuickSight datasets to JSON files and commits to Git
"""

import boto3
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path

# Configuration
AWS_ACCOUNT_ID = "046214330769"
AWS_REGION = "eu-central-1"  # Frankfurt
OUTPUT_DIR = "quicksight_datasets"

def setup_output_directory():
    """Create output directory if it doesn't exist"""
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
    print(f"✓ Output directory: {OUTPUT_DIR}")

def get_quicksight_client():
    """Initialize QuickSight client"""
    return boto3.client('quicksight', region_name=AWS_REGION)

def list_all_datasets(client):
    """List all datasets in the account"""
    print("\nFetching all datasets...")
    datasets = []
    next_token = None
    
    while True:
        if next_token:
            response = client.list_data_sets(
                AwsAccountId=AWS_ACCOUNT_ID,
                NextToken=next_token
            )
        else:
            response = client.list_data_sets(
                AwsAccountId=AWS_ACCOUNT_ID
            )
        
        datasets.extend(response.get('DataSetSummaries', []))
        next_token = response.get('NextToken')
        
        if not next_token:
            break
    
    print(f"✓ Found {len(datasets)} dataset(s)")
    return datasets

def export_dataset(client, dataset_id, dataset_name):
    """Export a single dataset definition"""
    try:
        response = client.describe_data_set(
            AwsAccountId=AWS_ACCOUNT_ID,
            DataSetId=dataset_id
        )
        
        # Remove response metadata
        if 'ResponseMetadata' in response:
            del response['ResponseMetadata']
        
        # Create safe filename from dataset name
        safe_name = "".join(c if c.isalnum() or c in ('-', '_') else '_' for c in dataset_name)
        filename = f"{safe_name}_{dataset_id}.json"
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        # Write to file with pretty formatting
        with open(filepath, 'w') as f:
            json.dump(response, f, indent=2, default=str)
        
        print(f"  ✓ Exported: {filename}")
        return True
        
    except Exception as e:
        print(f"  ✗ Error exporting {dataset_name}: {str(e)}")
        return False

def git_commit_changes():
    """Stage and commit changes to Git"""
    try:
        # Check if git repo exists
        subprocess.run(['git', 'rev-parse', '--git-dir'], 
                      check=True, capture_output=True, cwd='.')
        
        # Add all files in the output directory
        subprocess.run(['git', 'add', OUTPUT_DIR], check=True)
        
        # Check if there are changes to commit
        result = subprocess.run(['git', 'status', '--porcelain'], 
                               capture_output=True, text=True)
        
        if not result.stdout.strip():
            print("\n✓ No changes to commit")
            return True
        
        # Commit with timestamp
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        commit_message = f"Update QuickSight datasets - {timestamp}"
        
        subprocess.run(['git', 'commit', '-m', commit_message], check=True)
        print(f"\n✓ Changes committed: '{commit_message}'")
        return True
        
    except subprocess.CalledProcessError as e:
        if 'rev-parse' in str(e.cmd):
            print("\n⚠ Not a git repository. Initialize with 'git init' first.")
        else:
            print(f"\n✗ Git error: {str(e)}")
        return False

def main():
    """Main execution flow"""
    print("=" * 60)
    print("QuickSight Dataset Export Tool")
    print("=" * 60)
    print(f"AWS Account: {AWS_ACCOUNT_ID}")
    print(f"Region: {AWS_REGION}")
    
    # Setup
    setup_output_directory()
    client = get_quicksight_client()
    
    # List and export datasets
    datasets = list_all_datasets(client)
    
    if not datasets:
        print("\n⚠ No datasets found")
        return
    
    print(f"\nExporting datasets to {OUTPUT_DIR}/...")
    success_count = 0
    
    for dataset in datasets:
        dataset_id = dataset['DataSetId']
        dataset_name = dataset['Name']
        
        if export_dataset(client, dataset_id, dataset_name):
            success_count += 1
    
    print(f"\n{'=' * 60}")
    print(f"Export complete: {success_count}/{len(datasets)} datasets exported")
    print(f"{'=' * 60}")
    
    # Git commit
    git_commit_changes()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠ Export cancelled by user")
    except Exception as e:
        print(f"\n✗ Unexpected error: {str(e)}")

# QuickSight Dataset Version Control

This script exports all QuickSight datasets from your AWS account and commits them to Git for version control.

## Prerequisites

- Python 3.7+
- AWS CLI configured with appropriate credentials
- Git repository initialized
- IAM permissions for QuickSight

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure AWS Credentials

Ensure your AWS credentials are configured with QuickSight permissions:

```bash
aws configure
```

Required IAM permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "quicksight:ListDataSets",
                "quicksight:DescribeDataSet"
            ],
            "Resource": "*"
        }
    ]
}
```

### 3. Initialize Git Repository (if not already done)

```bash
git init
git add .
git commit -m "Initial commit"
```

## Usage

### Run the Export Script

```bash
python export_quicksight_datasets.py
```

### What It Does

1. Connects to AWS QuickSight in Frankfurt (eu-central-1) region
2. Lists all datasets in account 046214330769
3. Exports each dataset definition to `quicksight_datasets/` directory
4. Each dataset is saved as a separate JSON file: `{DatasetName}_{DatasetID}.json`
5. Automatically commits changes to Git with a timestamp message

### Output Structure

```
quicksight_datasets/
├── Sales_Dataset_abc123.json
├── Marketing_Data_def456.json
└── Customer_Analytics_ghi789.json
```

## Automation

### Schedule Regular Exports

Add to crontab for daily exports at 2 AM:

```bash
0 2 * * * cd /path/to/your/repo && python export_quicksight_datasets.py
```

## Workflow

### After Running the Script

```bash
# Check what changed
git status
git diff

# Push to remote (if needed)
git push origin main
```

## Troubleshooting

### "Not a git repository" Error
```bash
git init
git add .
git commit -m "Initial commit"
```

### AWS Credentials Not Found
```bash
aws configure
# Enter your Access Key ID, Secret Access Key, and region
```

### Permission Denied Error
- Verify your IAM user/role has QuickSight read permissions
- Check that your AWS credentials are valid

### No Datasets Found
- Confirm datasets exist in the Frankfurt region
- Verify you're using the correct AWS account ID

## Customization

Edit the script variables if needed:

```python
AWS_ACCOUNT_ID = "046214330769"  # Your AWS account
AWS_REGION = "eu-central-1"       # Frankfurt
OUTPUT_DIR = "quicksight_datasets" # Output directory
```

## Notes

- Dataset definitions do NOT include actual data, only metadata and schema
- Data source credentials are not exported
- The script uses `describe_data_set` API which provides full dataset configuration
- Files are overwritten on each export to track changes

## Next Steps

- Set up CI/CD pipeline to deploy datasets across environments
- Create diff scripts to compare dataset versions
- Add notifications for dataset changes
- Integrate with code review process

#!/usr/bin/env python3
"""
Script to extract SQL queries from QuickSight JSON files and save them as SQL files.
Finds all JSON files with 'score' in their names and the usda_psd_agg JSON file,
extracts SqlQuery elements, and saves them to a separate folder.
"""

import json
import os
from pathlib import Path


def extract_sql_query(json_file_path):
    """Extract SqlQuery from a QuickSight JSON file."""
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Navigate to PhysicalTableMap
        physical_table_map = data.get('DataSet', {}).get('PhysicalTableMap', {})
        
        if not physical_table_map:
            print(f"Warning: No PhysicalTableMap found in {json_file_path}")
            return None
        
        # Get the first table's SqlQuery (assuming there's at least one)
        for table_id, table_data in physical_table_map.items():
            custom_sql = table_data.get('CustomSql', {})
            sql_query = custom_sql.get('SqlQuery')
            
            if sql_query:
                return sql_query
        
        print(f"Warning: No SqlQuery found in {json_file_path}")
        return None
        
    except Exception as e:
        print(f"Error reading {json_file_path}: {e}")
        return None


def get_dataset_name(json_file_path):
    """Extract the dataset name from the JSON file."""
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        dataset_name = data.get('DataSet', {}).get('Name')
        return dataset_name or Path(json_file_path).stem
        
    except Exception as e:
        print(f"Error reading dataset name from {json_file_path}: {e}")
        return Path(json_file_path).stem


def main():
    # Define paths
    source_dir = Path(__file__).parent / 'quicksight_datasets'
    output_dir = Path(__file__).parent / 'sql_queries'
    
    # Create output directory if it doesn't exist
    output_dir.mkdir(exist_ok=True)
    
    # Find all JSON files with 'score' in their names
    score_files = list(source_dir.glob('*score*.json'))
    
    # Find usda_psd_agg JSON file
    usda_files = list(source_dir.glob('*usda_psd_agg*.json'))
    
    # Combine all files to process
    files_to_process = score_files + usda_files
    
    print(f"Found {len(files_to_process)} files to process:")
    for f in files_to_process:
        print(f"  - {f.name}")
    
    # Process each file
    success_count = 0
    for json_file in files_to_process:
        sql_query = extract_sql_query(json_file)
        
        if sql_query:
            dataset_name = get_dataset_name(json_file)
            sql_filename = f"{dataset_name}.sql"
            sql_file_path = output_dir / sql_filename
            
            # Write SQL query to file
            with open(sql_file_path, 'w', encoding='utf-8') as f:
                f.write(sql_query)
            
            print(f"✓ Extracted SQL query from {json_file.name} -> {sql_filename}")
            success_count += 1
        else:
            print(f"✗ Failed to extract SQL query from {json_file.name}")
    
    print(f"\nCompleted! Successfully extracted {success_count} SQL queries to {output_dir}")


if __name__ == '__main__':
    main()


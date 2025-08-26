#!/bin/bash

# Script to rename files/folders and replace content: Mirage->Fair, MIRAGE->FAIR, mirage->fair
# Usage: ./rename_script.sh [directory]

set -e  # Exit on error

# Default to current directory if no argument provided
TARGET_DIR="${1:-.}"

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

echo "Starting rename operations in: $TARGET_DIR"

# Function to check if path should be ignored
should_ignore() {
    local path="$1"
    local filename=$(basename "$path")
    
    # Check if it's the fairifier.sh script
    if [[ "$filename" == "fairifier.sh" ]]; then
        return 0  # Should ignore
    fi
    
    # Check if path contains any of the ignored directories
    if [[ "$path" == *"/.git/"* ]] || [[ "$path" == *"/.git" ]] || \
       [[ "$path" == *"/venv/"* ]] || [[ "$path" == *"/venv" ]] || \
       [[ "$path" == *"/__pycache__/"* ]] || [[ "$path" == *"/__pycache__" ]] || \
       [[ "$path" == *"/node_modules/"* ]] || [[ "$path" == *"/node_modules" ]] || \
       [[ "$path" == *"/build/"* ]] || [[ "$path" == *"/build" ]] || \
       [[ "$path" == *"/.react_router/"* ]] || [[ "$path" == *"/.react_router" ]] || \
       [[ "$path" == *".pyc" ]] || [[ "$path" == *".pyo" ]] || [[ "$path" == *".pyd" ]]; then
        return 0  # Should ignore
    fi
    return 1  # Should not ignore
}

# Function to replace content in files
replace_in_files() {
    echo "Step 1: Replacing content in files..."
    
    # Find all files, excluding ignored directories and binary files
    find "$TARGET_DIR" -type f -name "*" | while read -r file; do
        # Skip if should be ignored
        if should_ignore "$file"; then
            continue
        fi
        
        # Skip binary files by checking if file command indicates text
        if ! file "$file" | grep -q "text"; then
            continue
        fi
        
        # Check if file is readable and writable
        if [ ! -r "$file" ] || [ ! -w "$file" ]; then
            echo "Skipping $file (no read/write permission)"
            continue
        fi
        
        # Use sed to replace all three variations
        # Create a temporary file to avoid issues with in-place editing
        temp_file=$(mktemp)
        
        # Perform the replacements
        sed -e 's/Mirage/Fair/g' \
            -e 's/MIRAGE/FAIR/g' \
            -e 's/mirage/fair/g' \
            "$file" > "$temp_file"
        
        # Only replace if content actually changed
        if ! cmp -s "$file" "$temp_file"; then
            mv "$temp_file" "$file"
            echo "Updated content in: $file"
        else
            rm "$temp_file"
        fi
    done
    
    echo "Step 1 completed."
}

# Function to rename files
rename_files() {
    echo "Step 2: Renaming files..."
    
    # Find all files and process them
    find "$TARGET_DIR" -type f -name "*" | while read -r file; do
        # Skip if should be ignored
        if should_ignore "$file"; then
            continue
        fi
        
        # Get directory and filename
        dir=$(dirname "$file")
        filename=$(basename "$file")
        
        # Create new filename with replacements
        new_filename="$filename"
        new_filename="${new_filename//Mirage/Fair}"
        new_filename="${new_filename//MIRAGE/FAIR}"
        new_filename="${new_filename//mirage/fair}"
        
        # Rename if filename changed
        if [ "$filename" != "$new_filename" ]; then
            new_path="$dir/$new_filename"
            
            # If target already exists, remove it first
            if [ -e "$new_path" ]; then
                echo "Warning: Removing existing '$new_path' before rename"
                rm -rf "$new_path"
            fi
            
            mv "$file" "$new_path"
            echo "Renamed file: $filename -> $new_filename"
        fi
    done
    
    echo "Step 2 completed."
}

# Function to rename directories (from deepest to shallowest)
rename_directories() {
    echo "Step 3: Renaming directories (deepest first)..."
    
    # Create a temporary file to store directory list
    temp_dirs=$(mktemp)
    
    # Find all directories, sort by depth (deepest first)
    find "$TARGET_DIR" -type d -name "*" | \
    awk '{print length(gsub(/\//, "/")), $0}' | \
    sort -rn | \
    cut -d' ' -f2- > "$temp_dirs"
    
    # Process directories from the temp file
    while read -r dir; do
        # Skip if directory no longer exists (might have been renamed as part of parent)
        if [ ! -d "$dir" ]; then
            continue
        fi
        
        # Skip if should be ignored or if it's the target directory itself
        if should_ignore "$dir" || [ "$dir" = "$TARGET_DIR" ]; then
            continue
        fi
        
        # Get parent directory and directory name
        parent_dir=$(dirname "$dir")
        dir_name=$(basename "$dir")
        
        # Create new directory name with replacements
        new_dir_name="$dir_name"
        new_dir_name="${new_dir_name//Mirage/Fair}"
        new_dir_name="${new_dir_name//MIRAGE/FAIR}"
        new_dir_name="${new_dir_name//mirage/fair}"
        
        # Rename if directory name changed
        if [ "$dir_name" != "$new_dir_name" ]; then
            new_path="$parent_dir/$new_dir_name"
            
            # If target already exists, remove it first
            if [ -e "$new_path" ]; then
                echo "Warning: Removing existing '$new_path' before rename"
                rm -rf "$new_path"
            fi
            
            mv "$dir" "$new_path"
            echo "Renamed directory: $dir_name -> $new_dir_name"
        fi
    done < "$temp_dirs"
    
    # Clean up temporary file
    rm "$temp_dirs"
    
    echo "Step 3 completed."
}

# Main execution
echo "========================================"
echo "Recursive Rename Script"
echo "Mirage -> Fair, MIRAGE -> FAIR, mirage -> fair"
echo "========================================"

# Execute the three steps in order
replace_in_files
rename_files
rename_directories

echo "========================================"
echo "All operations completed successfully!"
echo "========================================"
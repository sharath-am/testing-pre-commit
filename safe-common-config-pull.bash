#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -t <file_type> [-d <directory_path>] [-v <version>]"
    echo "file_type: Specify the type of file to copy (e.g., 'pre-commit-config')"
    echo "directory_path: Optionally specify the directory to copy the file to (default is current directory)"
    echo "version: Optionally specify the version of the file to download (default is 'main')"
    echo "Available file types:"
    for key in "${FILE_TYPES[@]}"; do
        echo "  $key"
    done
    exit 1
}

# Mapping of file types to URLs (version placeholders)
FILE_TYPES=("pre-commit-config" "eslint")
FILE_URLS=(
    "https://raw.githubusercontent.com/sharath-am/testing-pre-commit/refs/heads/<version>/go/.pre-commit-config.yaml"
    "https://raw.githubusercontent.com/sharath-am/testing-pre-commit/refs/heads/<version>/go/.eslint.yaml"
)

# Function to get URL by file type
get_url_by_type() {
    local type=$1
    for i in "${!FILE_TYPES[@]}"; do
        if [ "${FILE_TYPES[$i]}" == "$type" ]; then
            echo "${FILE_URLS[$i]}"
            return 0
        fi
    done
    return 1
}

# Function to attempt downloading with retries
attempt_download() {
    local attempt=1
    local max_attempts=3
    local retry_delay=2

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt to download $FILE_NAME..."
        http_status=$(curl -s -o "$TARGET_PATH" -w "%{http_code}" "$REPO_URL")
        if [ "$http_status" -eq 200 ]; then
            return 0
        elif [ "$http_status" -eq 404 ]; then
            echo "Error: File not found (404)."
            return 1
        else
            echo "Download failed with status $http_status. Retrying in $retry_delay seconds..."
            sleep $retry_delay
            attempt=$((attempt + 1))
        fi
    done
    echo "Error: Failed to download $FILE_NAME after $max_attempts attempts."
    return 1
}

# Parse command-line arguments
DIRECTORY="."
VERSION="main"  # Default version (branch)
while getopts "t:d:v:" opt; do
    case "$opt" in
        t) FILE_TYPE=$OPTARG ;;
        d) DIRECTORY=$OPTARG ;;
        v) VERSION=$OPTARG ;;
        *) usage ;;
    esac
done

# Ensure the -t argument is provided
if [ -z "$FILE_TYPE" ]; then
    usage
fi

# Get the URL for the provided file type
REPO_URL=$(get_url_by_type "$FILE_TYPE")
if [ $? -ne 0 ]; then
    echo "Error: Unsupported file type '$FILE_TYPE'."
    usage
fi

# Validate the directory path
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist."
    exit 1
fi

# Set the file URL and file name, replacing the <version> placeholder with the actual version
REPO_URL="${REPO_URL//<version>/$VERSION}"
FILE_NAME=$(basename "$REPO_URL")  # Extract the file name from the URL
TARGET_PATH="$DIRECTORY/$FILE_NAME"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install curl to use this script."
    exit 1
fi

# Check if the file already exists in the target directory
if [ -f "$TARGET_PATH" ]; then
    echo "$TARGET_PATH already exists."

    # Ask the user if they want to overwrite it
    read -p "Do you want to overwrite the existing file? (y/N): " choice
    case "$choice" in
      y|Y ) echo "Overwriting $TARGET_PATH...";;
      * )
        read -p "Enter a custom extension to avoid conflict: " custom_ext
        TARGET_PATH="${TARGET_PATH}.${custom_ext}"
        echo "Downloading to $TARGET_PATH..."
        ;;
    esac
fi

# Download the specified file with retry mechanism
echo "Downloading $FILE_NAME from $REPO_URL to $DIRECTORY..."
if attempt_download; then
    echo "$FILE_NAME has been successfully downloaded to $DIRECTORY."
else
    echo "Error: Failed to download $FILE_NAME."
    exit 1
fi

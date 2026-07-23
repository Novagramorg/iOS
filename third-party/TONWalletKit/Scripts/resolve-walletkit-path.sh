#!/bin/bash
# Resolve WalletKit Path
# Returns the path to the walletkit repository, cloning it if necessary
set -e  # Exit on error

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the project root (parent of Scripts folder)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default walletkit folder name (in project root)
WALLETKIT_FOLDER="$PROJECT_ROOT/walletkit-git"
REPO_URL="https://github.com/ton-connect/kit.git"
BRANCH="main"

# Check if path parameter is provided
if [ -z "$1" ]; then
    # No path provided, use default walletkit folder
    
    # Create walletkit folder if it doesn't exist
    if [ ! -d "$WALLETKIT_FOLDER" ]; then
        echo "Creating $WALLETKIT_FOLDER folder..." >&2
        mkdir -p "$WALLETKIT_FOLDER"
    fi
    
    # Check if repo is already cloned
    if [ ! -d "$WALLETKIT_FOLDER/.git" ]; then
        echo "Cloning repository from $REPO_URL..." >&2
        git clone "$REPO_URL" "$WALLETKIT_FOLDER" >&2
        cd "$WALLETKIT_FOLDER"
        git checkout "$BRANCH" >&2
    else
        echo "Repository already cloned at $WALLETKIT_FOLDER" >&2
        cd "$WALLETKIT_FOLDER"
        
        # Check if we're on the correct branch
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
            echo "Switching to branch: $BRANCH" >&2
            git checkout "$BRANCH" >&2
        fi
        
        # Check for local changes
        if ! git diff-index --quiet HEAD --; then
            echo "Warning: Local changes detected in walletkit repository" >&2
            echo "Skipping git pull to preserve local changes" >&2
        else
            echo "Updating from remote..." >&2
            git pull origin "$BRANCH" >&2
        fi
    fi
    
    # Return the walletkit folder path
    echo "$WALLETKIT_FOLDER"
else
    # Path provided, validate and return it
    WALLETKIT_PATH="$1"
    
    # Check if provided path exists
    if [ ! -d "$WALLETKIT_PATH" ]; then
        echo "Error: Provided path does not exist: $WALLETKIT_PATH" >&2
        exit 1
    fi
    
    # Return the provided path (convert to absolute path)
    cd "$WALLETKIT_PATH"
    echo "$(pwd)"
fi

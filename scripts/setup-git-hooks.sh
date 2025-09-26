#!/bin/bash

# Setup script for Git hooks

set -e

echo "Setting up Git hooks for SimplyTrack..."

# Check if we're in the right directory
if [ ! -f "SimplyTrack.xcodeproj/project.pbxproj" ]; then
    echo "Error: This script must be run from the SimplyTrack project root directory"
    exit 1
fi

# Check if swift-format is installed
if ! command -v swift-format &> /dev/null; then
    echo "Installing swift-format..."
    if command -v brew &> /dev/null; then
        brew install swift-format
    else
        echo "Error: Homebrew not found. Please install swift-format manually:"
        echo "  brew install swift-format"
        exit 1
    fi
fi

# Copy pre-commit hook
echo "Installing pre-commit hook..."
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Pre-commit hook to format Swift files with swift-format

# Check if swift-format is available
if ! command -v swift-format &> /dev/null; then
    echo "Warning: swift-format not found. Please install it with:"
    echo "  brew install swift-format"
    echo "Skipping Swift formatting..."
    exit 0
fi

# Get list of Swift files that are staged for commit
SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.swift$')

if [ -z "$SWIFT_FILES" ]; then
    # No Swift files to format
    exit 0
fi

echo "Formatting Swift files with swift-format..."

# Format each Swift file
for file in $SWIFT_FILES; do
    if [ -f "$file" ]; then
        echo "Formatting: $file"
        swift-format --in-place "$file"
        # Re-add the formatted file to staging
        git add "$file"
    fi
done

echo "Swift formatting complete."
EOF

chmod +x .git/hooks/pre-commit

echo "Git hooks setup complete!"
echo ""
echo "The pre-commit hook will automatically format Swift files using swift-format."
echo "Configuration is stored in .swift-format file."
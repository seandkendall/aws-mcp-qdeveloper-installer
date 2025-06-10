#!/bin/bash

# Amazon Q Developer Pro MCP Installation Script
# Built by Sean Kendall - Principal Solutions Architect (seandall@amazon.com)
#
# This script installs MCP servers for Amazon Q Developer Pro

# Set default values
DEBUG=false
GITHUB_TOKEN=""
REINSTALL=false
VERBOSE=false
COLOR_SUPPORT=true
PLATFORM="$(uname -s)"
Q_CONFIG_DIR="$HOME/.aws/amazonq"

# Color codes for output
if [ "$COLOR_SUPPORT" = true ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Function to display help information
display_help() {
    echo "Amazon Q Developer Pro MCP Installation Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Display this help message and exit"
    echo "  -d, --debug      Enable debug mode (show detailed command output)"
    echo "  -g <token>       Set GitHub token for git-repo-research-mcp-server"
    echo "                   Token will be saved for future use"
    echo "  -r, --reinstall  Reinstall Amazon Q Developer and clear history/logs"
    echo "  -v, --verbose    Show more detailed progress information"
    echo "  --no-color       Disable colored output"
    echo ""
    echo "Examples:"
    echo "  $0                           # Standard installation"
    echo "  $0 -g ghp_abc123def456       # Install with GitHub token"
    echo "  $0 -d -r                     # Reinstall with debug output"
    echo "  $0 --reinstall --debug       # Same as above with long options"
    echo ""
    exit 0
}

# Function for logging messages with colors
log_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

log_debug() {
    if [ "$DEBUG" = true ] || [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}DEBUG:${NC} $1"
    fi
}

# Function to execute commands with proper logging
execute_command() {
    local cmd="$1"
    local description="$2"
    local exit_on_error="${3:-true}"
    
    if [ "$DEBUG" = true ]; then
        log_debug "Running command: $cmd"
    fi
    
    OUTPUT=$(eval "$cmd" 2>&1)
    EXIT_CODE=$?
    
    if [ "$DEBUG" = true ]; then
        log_debug "Command output:"
        echo "$OUTPUT"
        log_debug "Exit code: $EXIT_CODE"
        echo ""
    fi
    
    if [ $EXIT_CODE -ne 0 ]; then
        log_error "$description failed."
        if [ "$VERBOSE" = true ] || [ "$DEBUG" = true ]; then
            echo "$OUTPUT"
        fi
        if [ "$exit_on_error" = true ]; then
            exit 1
        fi
        return 1
    else
        if [ -n "$description" ]; then
            log_success "$description"
        fi
        return 0
    fi
}

# Function to check and install dependencies
check_dependency() {
    local cmd="$1"
    local name="$2"
    local install_cmd="$3"
    local check_version_cmd="${4:-$cmd --version}"
    
    log_info "Checking if $name is installed..."
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$name is not installed. Attempting to install..."
        
        # Check if Homebrew is installed for macOS
        if [[ "$PLATFORM" == "Darwin" && "$install_cmd" == *"brew"* ]]; then
            if ! command -v brew &> /dev/null; then
                log_error "Homebrew is not installed. Please install Homebrew first."
                log_info "Visit https://brew.sh/ for installation instructions."
                return 1
            fi
        fi
        
        execute_command "$install_cmd" "Installing $name" false
        
        # Check again after installation attempt
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Failed to install $name. Please install it manually."
            return 1
        fi
    fi
    
    # Get version information
    VERSION=$(eval "$check_version_cmd" 2>&1)
    log_success "$name is installed: $VERSION"
    return 0
}

# Function to validate GitHub token format
validate_github_token() {
    local token="$1"
    
    # Basic validation - GitHub tokens are typically 40 characters long
    # and start with "ghp_", "gho_", "ghu_", or "ghs_"
    if [[ ! "$token" =~ ^(ghp_|gho_|ghu_|ghs_)[a-zA-Z0-9]{36,40}$ ]]; then
        log_warning "The GitHub token format appears to be invalid."
        log_info "GitHub tokens typically start with 'ghp_', 'gho_', 'ghu_', or 'ghs_' followed by 36-40 alphanumeric characters."
        read -p "Do you want to continue with this token anyway? (y/n): " CONTINUE_WITH_TOKEN
        if [[ "$CONTINUE_WITH_TOKEN" != "y" && "$CONTINUE_WITH_TOKEN" != "Y" ]]; then
            log_error "GitHub token validation failed. Exiting."
            exit 1
        fi
    fi
}

# Function to handle cleanup on script termination
cleanup() {
    log_info "Cleaning up temporary files..."
    # Remove any temporary files created by the script
    if [ -n "$TMP_FILE" ] && [ -f "$TMP_FILE" ]; then
        rm -f "$TMP_FILE"
    fi
    log_info "Cleanup completed."
}

# Register the cleanup function to be called on exit
trap cleanup EXIT

# Parse command line arguments
while getopts "hdg:rv-:" opt; do
  case ${opt} in
    h)
      display_help
      ;;
    d)
      DEBUG=true
      ;;
    g)
      GITHUB_TOKEN=$OPTARG
      ;;
    r)
      REINSTALL=true
      ;;
    v)
      VERBOSE=true
      ;;
    -)
      case "${OPTARG}" in
        help)
          display_help
          ;;
        debug)
          DEBUG=true
          ;;
        reinstall)
          REINSTALL=true
          ;;
        verbose)
          VERBOSE=true
          ;;
        no-color)
          COLOR_SUPPORT=false
          RED=''
          GREEN=''
          YELLOW=''
          BLUE=''
          NC=''
          ;;
        *)
          log_error "Invalid option: --${OPTARG}"
          log_info "Try '$0 --help' for more information."
          exit 1
          ;;
      esac
      ;;
    \?)
      log_error "Invalid option: -$OPTARG"
      log_info "Try '$0 --help' for more information."
      exit 1
      ;;
    :)
      log_error "Option -$OPTARG requires an argument."
      log_info "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

# Check for legacy flag formats (for backward compatibility)
for arg in "$@"; do
  if [ "$arg" == "--debug" ]; then
    DEBUG=true
  elif [ "$arg" == "--reinstall" ]; then
    REINSTALL=true
  elif [ "$arg" == "--verbose" ]; then
    VERBOSE=true
  elif [ "$arg" == "--no-color" ]; then
    COLOR_SUPPORT=false
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
  elif [ "$arg" == "--help" ] || [ "$arg" == "-help" ]; then
    display_help
  fi
done

# Display header
echo "==============================================================="
echo "Amazon Q Developer Pro MCP Installation Script"
echo "Built by Sean Kendall - Principal Solutions Architect (seandall@amazon.com)"
echo "==============================================================="
echo ""
echo "This script will:"
echo "1. Check if AWS CLI is installed and configured"
echo "2. Check if uv is installed (and install it if needed)"
echo "3. Install MCP servers for Amazon Q Developer Pro"
if [ "$REINSTALL" = true ]; then
  echo "4. Reinstall Amazon Q Developer and clear history/logs"
fi
echo ""

if [ "$DEBUG" = true ]; then
  log_info "Debug mode enabled. Commands and their outputs will be displayed."
  echo ""
fi

if [ "$VERBOSE" = true ]; then
  log_info "Verbose mode enabled. Additional information will be displayed."
  echo ""
fi

# Platform-specific settings
log_info "Detected platform: $PLATFORM"
case "$PLATFORM" in
  Darwin)
    log_info "Running on macOS"
    PACKAGE_MANAGER="brew"
    ;;
  Linux)
    log_info "Running on Linux"
    if command -v apt-get &> /dev/null; then
      PACKAGE_MANAGER="apt"
    elif command -v yum &> /dev/null; then
      PACKAGE_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
      PACKAGE_MANAGER="dnf"
    else
      log_warning "Unsupported Linux distribution. Package installation may fail."
      PACKAGE_MANAGER="unknown"
    fi
    ;;
  *)
    log_warning "Unsupported platform: $PLATFORM. This script is optimized for macOS and Linux."
    ;;
esac

# Create the .aws/amazonq directory if it doesn't exist
if [ ! -d "$Q_CONFIG_DIR" ]; then
    log_info "Creating Amazon Q config directory at $Q_CONFIG_DIR"
    mkdir -p "$Q_CONFIG_DIR"
    if [ $? -ne 0 ]; then
        log_error "Failed to create directory: $Q_CONFIG_DIR"
        exit 1
    fi
fi

# Handle reinstall if requested
if [ "$REINSTALL" = true ]; then
    log_info "Reinstall requested. Cleaning up history and logs..."
    
    # Clear history directory
    if [ -d "$Q_CONFIG_DIR/history" ]; then
        log_info "Removing history directory: $Q_CONFIG_DIR/history"
        rm -rf "$Q_CONFIG_DIR/history"
        mkdir -p "$Q_CONFIG_DIR/history"
    else
        mkdir -p "$Q_CONFIG_DIR/history"
    fi
    
    # Remove log file
    if [ -f "$Q_CONFIG_DIR/lspLog.log" ]; then
        log_info "Removing log file: $Q_CONFIG_DIR/lspLog.log"
        rm -f "$Q_CONFIG_DIR/lspLog.log"
    fi
    
    log_success "Cleanup completed."
fi

# Check dependencies
check_dependency "aws" "AWS CLI" "echo 'Please install AWS CLI manually from https://aws.amazon.com/cli/'" || exit 1

# Check if AWS CLI is configured
execute_command "aws sts get-caller-identity" "AWS CLI is configured" true

# Check for other dependencies
if [[ "$PLATFORM" == "Darwin" ]]; then
    check_dependency "uv" "uv" "brew install uv"
    check_dependency "jq" "jq" "brew install jq" || log_warning "jq installation failed. Will use fallback method for JSON parsing."
    check_dependency "q" "Amazon Q CLI" "brew install amazon-q"
else
    # For Linux, we need different installation commands
    check_dependency "uv" "uv" "pip install uv"
    check_dependency "jq" "jq" "sudo apt-get install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null || sudo dnf install -y jq 2>/dev/null" || log_warning "jq installation failed. Will use fallback method for JSON parsing."
    log_warning "For Linux, please install Amazon Q CLI manually from: https://aws.amazon.com/q/developer/"
    # Check if q is installed anyway
    if command -v q &> /dev/null; then
        Q_PATH=$(which q)
        log_success "Amazon Q CLI is installed at: $Q_PATH"
    else
        log_warning "Amazon Q CLI is not installed. Please install it manually."
    fi
fi

# If reinstall is requested for Amazon Q CLI
if [ "$REINSTALL" = true ] && command -v q &> /dev/null; then
    log_info "Reinstall requested for Amazon Q CLI..."
    
    # Try to uninstall and reinstall with Homebrew on macOS
    if [[ "$PLATFORM" == "Darwin" ]] && command -v brew &> /dev/null; then
        log_info "Attempting to reinstall Amazon Q with Homebrew..."
        
        # First try to uninstall the cask if it exists
        execute_command "brew uninstall --cask amazon-q || true" "Uninstalling Amazon Q" false
        
        # If the app exists, try to remove it manually
        if [ -d "/Applications/Amazon Q.app" ]; then
            log_info "Removing existing Amazon Q application..."
            execute_command "rm -rf '/Applications/Amazon Q.app'" "Removing Amazon Q application" false
        fi
        
        # Then reinstall
        execute_command "brew install --cask amazon-q" "Reinstalling Amazon Q CLI" false
    else
        log_warning "Automatic reinstallation is only supported on macOS with Homebrew."
        log_info "Please reinstall Amazon Q CLI manually from: https://aws.amazon.com/q/developer/"
    fi
fi

# Handle GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    # No GitHub token provided via command line, check if we have a saved one
    if [ -f "$Q_CONFIG_DIR/github_token.txt" ]; then
        log_info "Using saved GitHub token from $Q_CONFIG_DIR/github_token.txt"
        GITHUB_TOKEN=$(cat "$Q_CONFIG_DIR/github_token.txt")
    fi
else
    # Validate the GitHub token format
    validate_github_token "$GITHUB_TOKEN"
    
    # Save the provided GitHub token
    log_info "Saving GitHub token to $Q_CONFIG_DIR/github_token.txt"
    echo "$GITHUB_TOKEN" > "$Q_CONFIG_DIR/github_token.txt"
    chmod 600 "$Q_CONFIG_DIR/github_token.txt"
fi

# Create backup of existing mcp.json if it exists
ADDITIONAL_SERVERS=""
if [ -f "$Q_CONFIG_DIR/mcp.json" ]; then
    TIMESTAMP=$(date +"%Y-%m-%d-%H:%M:%S")
    BACKUP_FILE="$Q_CONFIG_DIR/mcp-backup-$TIMESTAMP.json"
    log_info "Creating backup of existing mcp.json to $BACKUP_FILE"
    cp "$Q_CONFIG_DIR/mcp.json" "$BACKUP_FILE"
    
    # Check for additional MCP servers that aren't in our default list
    log_info "Scanning existing mcp.json for additional MCP servers..."
    
    # Use jq to properly extract the server names from the JSON structure
    # This is much more reliable than using grep/sed for JSON parsing
    if command -v jq &> /dev/null; then
        # Use jq to extract the keys from the mcpServers object
        EXISTING_SERVERS=$(jq -r '.mcpServers | keys[]' "$Q_CONFIG_DIR/mcp.json")
    else
        # Fallback to a more careful grep approach if jq is not available
        # This pattern looks for lines that match the pattern of a server name at the start of a line
        # with proper indentation (exactly 2 tabs)
        EXISTING_SERVERS=$(grep -o '		"[^"]*": {' "$Q_CONFIG_DIR/mcp.json" | sed 's/		"//g' | sed 's/": {//g')
    fi
    
    # Initialize a variable to store additional servers
    for server in $EXISTING_SERVERS; do
        # Check if the server contains "awslabs", "duckduckgo", or "strands"
        if [[ "$server" != *"awslabs"* ]] && [[ "$server" != "duckduckgo" ]] && [[ "$server" != "strands" ]]; then
            if [ -z "$ADDITIONAL_SERVERS" ]; then
                ADDITIONAL_SERVERS="$server"
            else
                ADDITIONAL_SERVERS="$ADDITIONAL_SERVERS $server"
            fi
        fi
    done
    
    # If there are additional servers, ask the user if they want to include them
    if [ ! -z "$ADDITIONAL_SERVERS" ]; then
        echo ""
        log_info "Found additional MCP servers in your existing configuration:"
        for server in $ADDITIONAL_SERVERS; do
            echo "  - $server"
        done
        echo ""
        read -p "Would you like to include these additional MCP servers? (y/n): " INCLUDE_ADDITIONAL
        echo ""
    fi
fi

# Create a temporary file for building the JSON
TMP_FILE=$(mktemp)
log_debug "Created temporary file: $TMP_FILE"

# Start building the JSON content
log_info "Creating MCP configuration at $Q_CONFIG_DIR/mcp.json"

# Write the base configuration to the temporary file
cat > "$TMP_FILE" << 'EOF'
{
	"mcpServers": {
		"awslabs.aws-diagram-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.aws-diagram-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"autoApprove": ["*"],
			"disabled": false
		},
		"awslabs.aws-documentation-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.aws-documentation-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.cdk-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.cdk-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.core-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.core-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"autoApprove": ["*"],
			"disabled": false
		},
		"awslabs.cost-analysis-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.cost-analysis-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.nova-canvas-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.nova-canvas-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.aws-location-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.aws-location-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.git-research": {
			"command": "uvx",
			"args": ["awslabs.git-repo-research-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.cloudformation": {
			"command": "uvx",
			"args": ["awslabs.cfn-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default"
			},
			"disabled": false,
			"autoApprove": ["*"]
		},
		"awslabs.aws-serverless-mcp-server": {
			"command": "uvx",
			"args": [
				"awslabs.aws-serverless-mcp-server@latest",
				"--allow-write",
				"--allow-sensitive-data-access"
			],
			"env": {
				"AWS_PROFILE": "default"
			},
			"disabled": false,
			"autoApprove": [],
			"timeout": 60
		},
		"awslabs.syntheticdata-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.syntheticdata-mcp-server@latest"],
			"env": {
				"FASTMCP_LOG_LEVEL": "ERROR",
				"AWS_PROFILE": "default"
			},
			"autoApprove": [],
			"disabled": false
		},
		"awslabs.code-doc-gen-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.code-doc-gen-mcp-server@latest"],
			"env": {
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": []
		},
		"awslabs.frontend-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.frontend-mcp-server@latest"],
			"env": {
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": []
		},
		"awslabs.dynamodb-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.dynamodb-mcp-server@latest"],
			"env": {
				"DDB-MCP-READONLY": "true",
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR"
			},
			"disabled": false,
			"autoApprove": []
		},
		"duckduckgo": {
			"command": "uvx",
			"args": ["ddg-mcp-server"]
		},
		"strands": {
			"command": "uvx",
			"args": ["strands-agents-mcp-server"]
		}
EOF

# Add git-repo-research-mcp-server only if we have a GitHub token
if [ -n "$GITHUB_TOKEN" ]; then
    log_info "Adding git-repo-research-mcp-server with GitHub token"
    cat >> "$TMP_FILE" << EOF
,
		"awslabs.git-repo-research-mcp-server": {
			"command": "uvx",
			"args": ["awslabs.git-repo-research-mcp-server@latest"],
			"env": {
				"AWS_PROFILE": "default",
				"FASTMCP_LOG_LEVEL": "ERROR",
				"GITHUB_TOKEN": "$GITHUB_TOKEN"
			},
			"disabled": false,
			"autoApprove": ["*"]
		}
EOF
fi

# Close the JSON structure
cat >> "$TMP_FILE" << 'EOF'
	}
}
EOF

# Add additional servers if the user chose to include them
if [ ! -z "$ADDITIONAL_SERVERS" ] && [ "$INCLUDE_ADDITIONAL" = "y" ]; then
    log_info "Adding additional MCP servers from your existing configuration..."
    
    # Create a second temporary file for the updated JSON
    TMP_FILE2=$(mktemp)
    
    # Extract the additional server configurations from the backup file and add them to the new mcp.json
    for server in $ADDITIONAL_SERVERS; do
        # Skip if the server is duckduckgo or strands (they're already included)
        if [[ "$server" == "duckduckgo" ]] || [[ "$server" == "strands" ]]; then
            log_info "  - Skipping $server (already included in default configuration)"
            continue
        fi
        
        # Extract the server configuration from the backup file
        # We need to extract the complete server configuration block
        SERVER_START=$(grep -n "		\"$server\": {" "$BACKUP_FILE" | cut -d: -f1)
        
        if [ -n "$SERVER_START" ]; then
            # Find the matching closing brace for this server block
            # This is more complex but more reliable than the previous approach
            SERVER_CONFIG=$(sed -n "${SERVER_START},/^		}/p" "$BACKUP_FILE")
            
            # Use jq to add the server configuration if available
            if command -v jq &> /dev/null; then
                # Extract the server configuration as JSON
                SERVER_JSON=$(echo "$SERVER_CONFIG" | sed 's/^		"'"$server"'": //')
                
                # Use jq to add the server to the configuration
                jq --arg server "$server" '.mcpServers[$server] = '"$SERVER_JSON" "$TMP_FILE" > "$TMP_FILE2"
                mv "$TMP_FILE2" "$TMP_FILE"
            else
                # Fallback to sed-based approach
                # Remove the closing brace and add a comma to the end of the mcpServers object
                sed -i '' -e '$d' -e '$d' "$TMP_FILE"
                echo "," >> "$TMP_FILE"
                
                # Add the server configuration
                echo "$SERVER_CONFIG" >> "$TMP_FILE"
                
                # Close the JSON structure again
                echo "	}" >> "$TMP_FILE"
                echo "}" >> "$TMP_FILE"
            fi
            
            log_success "  - Added $server"
        else
            log_warning "  - Could not find configuration for $server, skipping"
        fi
    done
    
    log_success "Additional MCP servers added successfully."
fi

# Move the temporary file to the final location
mv "$TMP_FILE" "$Q_CONFIG_DIR/mcp.json"

# Set appropriate permissions for the mcp.json file
chmod 600 "$Q_CONFIG_DIR/mcp.json"

log_success "MCP configuration created successfully."

# Verify the installation
log_info "Verifying MCP configuration..."
if [ -f "$Q_CONFIG_DIR/mcp.json" ]; then
    # Check if the file is valid JSON
    if command -v jq &> /dev/null; then
        if jq empty "$Q_CONFIG_DIR/mcp.json" 2>/dev/null; then
            log_success "MCP configuration is valid JSON."
        else
            log_warning "MCP configuration may not be valid JSON. Please check the file manually."
        fi
    fi
else
    log_error "MCP configuration file was not created successfully."
    exit 1
fi

echo ""
log_success "MCP installation completed. You can now use Amazon Q with the installed MCP servers."
log_info "To verify the installation, run: q mcp list"
echo ""
log_info "For help with this script, run: $0 --help"

# Display version information
echo ""
log_info "Installation Summary:"
echo "  Platform: $PLATFORM"
if command -v q &> /dev/null; then
    Q_VERSION=$(q --version 2>&1 || echo "Unknown")
    echo "  Amazon Q CLI Version: $Q_VERSION"
fi
if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version 2>&1 || echo "Unknown")
    echo "  uv Version: $UV_VERSION"
fi
echo "  Configuration Directory: $Q_CONFIG_DIR"
echo ""

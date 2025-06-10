# AWS MCP Q Developer Installer

A script to install and configure MCP servers for Amazon Q Developer Pro.

## Features

- Installs and configures all required MCP servers for Amazon Q Developer Pro
- Supports macOS and Linux environments
- Handles GitHub token configuration for git-repo-research-mcp-server
- Provides options for reinstallation and debugging
- Preserves custom MCP server configurations

## Usage

```bash
./install_mcp.sh [options]
```

### Options

- `-h, --help`: Display help information and exit
- `-d, --debug`: Enable debug mode (show detailed command output)
- `-g <token>`: Set GitHub token for git-repo-research-mcp-server
- `-r, --reinstall`: Reinstall Amazon Q Developer and clear history/logs
- `-v, --verbose`: Show more detailed progress information
- `--no-color`: Disable colored output

### Examples

```bash
./install_mcp.sh                           # Standard installation
./install_mcp.sh -g ghp_abc123def456       # Install with GitHub token
./install_mcp.sh -d -r                     # Reinstall with debug output
./install_mcp.sh --reinstall --debug       # Same as above with long options
```

## Requirements

- AWS CLI installed and configured
- macOS or Linux operating system
- Internet connection to download dependencies

## License

This project is licensed under the MIT License - see the LICENSE file for details.

# ProxyWrap - Advanced ProxyChains Tool

ProxyWrap is a powerful bash script that provides an enhanced interface for ProxyChains, making it easier to manage and use proxy configurations with advanced features like validation, profiles, and interactive selection.

## Features

- **Multiple Proxy Support**: Add proxies individually or load from files
- **Proxy Validation**: Test proxy connectivity before use
- **Profile Management**: Save and load proxy configurations
- **Interactive Mode**: Select proxies interactively
- **Chain Types**: Support for strict and random chain modes
- **Retry Logic**: Automatic retry on command failure
- **Export Functionality**: Export ProxyChains configurations
- **Dry Run Mode**: Preview configurations without execution
- **Verbose Output**: Detailed logging and configuration display

## Prerequisites

- `proxychains` must be installed and available in PATH
- Bash shell (version 4.0 or higher recommended)
- Standard Unix utilities (timeout, mktemp, etc.)

### Installing ProxyChains

**Ubuntu/Debian:**
```bash
sudo apt-get install proxychains
```

**CentOS/RHEL:**
```bash
sudo yum install proxychains-ng
```

**macOS:**
```bash
brew install proxychains-ng
```

## Installation

1. Download the script:
```bash
curl -O https://raw.githubusercontent.com/yourrepo/proxywrap/main/proxywrap.sh
```

2. Make it executable:
```bash
chmod +x proxywrap.sh
```

3. Optionally, move to a directory in your PATH:
```bash
sudo mv proxywrap.sh /usr/local/bin/proxywrap
```

## Usage

### Basic Syntax
```bash
./proxywrap.sh [options] -- <command>
```

### Options

| Option | Description |
|--------|-------------|
| `-p <proxy>` | Add proxy (format: "socks5 127.0.0.1 9050") |
| `-P <file>` | Load proxies from file |
| `-r` | Use random_chain instead of strict_chain |
| `-n` | Disable proxy_dns |
| `-i` | Interactive proxy selection |
| `-d` | Dry-run mode (don't execute command) |
| `--retry <N>` | Retry the command N times if it fails |
| `--delay <sec>` | Random delay between proxies |
| `--profile <name>` | Load/save a proxy profile |
| `--validate` | Validate proxies before use |
| `--export <file>` | Export proxychains config to file |
| `--timeout <sec>` | Connection timeout for validation (default: 5) |
| `--list-profiles` | List available profiles |
| `--remove-profile <name>` | Remove a profile |
| `-v, --verbose` | Verbose output |
| `-h, --help` | Show help menu |

### Proxy Formats

ProxyWrap supports three proxy protocols:
- `socks4 <host> <port>`
- `socks5 <host> <port>`
- `http <host> <port>`

## Examples

### Basic Usage

Run curl through a single SOCKS5 proxy:
```bash
./proxywrap.sh -p "socks5 127.0.0.1 9050" -- curl http://ifconfig.me
```

### Multiple Proxies

Use multiple proxies in random chain mode:
```bash
./proxywrap.sh -r -p "socks5 127.0.0.1 9050" -p "http 192.168.1.100 8080" -- curl http://ifconfig.me
```

### Load Proxies from File

Create a proxy file (`proxies.txt`):
```
socks5 127.0.0.1 9050
http 192.168.1.100 8080
socks4 10.0.0.1 1080
```

Then use it:
```bash
./proxywrap.sh -P proxies.txt -- curl http://ifconfig.me
```

### Profile Management

Save a proxy configuration as a profile:
```bash
./proxywrap.sh -p "socks5 127.0.0.1 9050" --profile myvpn -- curl http://ifconfig.me
```

Load and use a saved profile:
```bash
./proxywrap.sh --profile myvpn -- firefox
```

List available profiles:
```bash
./proxywrap.sh --list-profiles
```

### Proxy Validation

Validate proxies before use:
```bash
./proxywrap.sh -P proxies.txt --validate --timeout 10 -- curl http://ifconfig.me
```

### Interactive Mode

Select proxies interactively:
```bash
./proxywrap.sh -P proxies.txt -i -- curl http://ifconfig.me
```

### Advanced Usage

Combine multiple features:
```bash
./proxywrap.sh --profile myvpn --validate -i --retry 3 --delay 2 -v -- curl http://ifconfig.me
```

### Dry Run

Preview configuration without execution:
```bash
./proxywrap.sh -p "socks5 127.0.0.1 9050" -d -- curl http://ifconfig.me
```

### Export Configuration

Export ProxyChains configuration to a file:
```bash
./proxywrap.sh -p "socks5 127.0.0.1 9050" --export /tmp/proxychains.conf
```

## Configuration Files

### Profile Storage
Profiles are stored in `~/.proxywrap/` directory as `.profile` files.

### Proxy File Format
Proxy files should contain one proxy per line in the format:
```
protocol host port
```

Comments (lines starting with #) and empty lines are ignored.

Example:
```
# My proxy list
socks5 127.0.0.1 9050
http 192.168.1.100 8080
# Another proxy
socks4 10.0.0.1 1080
```

## Chain Types

### Strict Chain (default)
Proxies are used in the exact order specified. If any proxy fails, the connection fails.

### Random Chain
A random proxy is selected from the list for each connection.

Usage:
```bash
./proxywrap.sh -r -P proxies.txt -- curl http://ifconfig.me
```

## Error Handling

ProxyWrap includes comprehensive error handling:
- Validates proxy formats
- Checks for required dependencies
- Provides clear error messages
- Supports retry logic for failed commands
- Graceful cleanup of temporary files

## Troubleshooting

### Common Issues

1. **Command not found: proxychains**
   - Install proxychains using your package manager
   - Ensure proxychains is in your PATH

2. **Permission denied**
   - Make sure the script is executable: `chmod +x proxywrap.sh`

3. **Proxy connection failed**
   - Use `--validate` to test proxy connectivity
   - Check proxy server status and credentials
   - Verify firewall settings

4. **Profile not found**
   - Use `--list-profiles` to see available profiles
   - Check if profile exists in `~/.proxywrap/`

### Verbose Mode

Use `-v` or `--verbose` for detailed output:
```bash
./proxywrap.sh -v -p "socks5 127.0.0.1 9050" -- curl http://ifconfig.me
```

## Security Considerations

- Proxy credentials are not encrypted in profile files
- Use appropriate file permissions for proxy configuration files
- Be cautious when using untrusted proxy servers
- Consider using VPN in addition to proxies for enhanced security

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve ProxyWrap.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### Version 1.0.0
- Initial release
- Basic proxy management
- Profile system
- Validation functionality
- Interactive mode
- Export capabilities
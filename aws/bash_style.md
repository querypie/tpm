# Bash Coding Style Guide

This document outlines the bash coding style conventions used in the QueryPie project, based on the analysis of `setup.v2.sh`.

## Table of Contents

1. [File Structure](#file-structure)
2. [Variable Declarations](#variable-declarations)
3. [Function Definitions](#function-definitions)
4. [Control Structures](#control-structures)
5. [String Handling](#string-handling)
6. [Error Handling](#error-handling)
7. [Logging and Output](#logging-and-output)
8. [Command Execution](#command-execution)
9. [File Operations](#file-operations)
10. [Comments and Documentation](#comments-and-documentation)
11. [Best Practices](#best-practices)
12. [Shell Compatibility](#shell-compatibility)
13. [Code Quality Tools](#code-quality-tools)

## File Structure

### Script Header
```bash
#!/usr/bin/env bash
# This script provides a quick and easy way to install QueryPie.
# Run the following commands:
# $ bash <(curl -s https://dl.querypie.com/setup.v2.sh)
# or
# $ curl -s https://dl.querypie.com/setup.v2.sh -o setup.v2.sh
# $ bash setup.v2.sh --install <version>
# $ bash setup.v2.sh --upgrade <version>

# The version will be manually increased by the author.
SCRIPT_VERSION="25.08.1" # YY.MM.PATCH
```

### Version Information
- Use semantic versioning format: `YY.MM.PATCH`
- Include version in script header with clear comment
- Display version information at script start

### Script Information Display
```bash
echo -n "#### QueryPie Installer ${SCRIPT_VERSION}, " >&2
echo -n "${BASH:-}${ZSH_NAME:-} ${BASH_VERSION:-}${ZSH_VERSION:-}" >&2
echo >&2 " on $(uname -s) $(uname -m) ####"
```

## Variable Declarations

### Global Variables
```bash
RECOMMENDED_VERSION="11.0.1" # QueryPie version to install by default.
ASSUME_YES=false
DOCKER=docker          # The default docker command
COMPOSE=docker-compose # The default compose command
```

### Variable Naming
- Use UPPER_CASE for global constants and configuration
- Use descriptive names with underscores
- Include comments for non-obvious variables
- Use lowercase for local variables

### Array Declarations
```bash
declare -a SUDO=(sudo)
```

### Variable Expansion
```bash
# Use parameter expansion with defaults
local user
user="$(id -un 2>/dev/null || true)"

# Use indirect expansion for dynamic variable names
if [[ -n "${!name+_}" ]]; then
  echo "${!name}"
  return
fi

# Use arithmetic expansion for calculations
repeated=$((repeated + 1))
elapsed=$((ended_at - started_at))
```

## Function Definitions

### Function Naming Convention
Use namespace prefixes with double colons:
```bash
function log::do() {
  # Function implementation
}

function install::docker() {
  # Function implementation
}

function cmd::install() {
  # Function implementation
}
```

### Function Structure
```bash
function function_name() {
  local param1=$1 param2=$2
  
  # Function body
  # Return statements
}
```

### Local Variables
Always declare local variables at the beginning:
```bash
function example() {
  local var1 var2 var3
  var1=$1
  var2=$2
  var3=$3
}
```

## Control Structures

### If Statements
```bash
if [[ "${user}" == 'root' ]]; then
  echo >&2 "# The current user is 'root'. No need to use sudo."
  SUDO=() # No need to use sudo.
elif command_exists sudo; then
  echo >&2 "# 'sudo' will be used for privileged commands."
  SUDO=(sudo)
else
  log::error "This installer needs the ability to run commands as root."
  log::error "We are unable to find 'sudo' available to make this happen."
  exit 1
fi
```

### Case Statements
```bash
case "$lsb_id" in
amzn)
  case "$lsb_id_like" in
  fedora)
    log::sudo dnf install -y docker
    ;;
  *)
    log::sudo amazon-linux-extras install -y docker
    ;;
  esac
  ;;
rocky)
  log::sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
  log::sudo dnf install -y docker-ce
  ;;
*)
  log::do curl -fsSL https://get.docker.com -o docker-install.sh
  log::sudo sh docker-install.sh
  ;;
esac
```

### Loops
```bash
# For loop with range
for i in {1..300}; do
  if [[ "$(tools::get_readyz)" == "200" ]]; then
    repeated=$((repeated + 1))
    if ((repeated >= 3)); then
      return 0
    fi
  else
    repeated=0
  fi
  sleep 1
done

# While loop with file reading
while IFS= read -r -u 9 line; do
  if [[ -z "${line}" || "${line}" =~ ^\s*# ]]; then
    echo "${line}"
    continue
  fi
  # Process line
done 9<"${source_env}"
```

## String Handling

### String Comparison
```bash
# Use double brackets for string comparisons
if [[ "${user}" == 'root' ]]; then
  # Action
fi

# Use regex matching
if [[ "${line}" =~ ^\s*# ]]; then
  # Skip comments
fi
```

### String Manipulation
```bash
# Parameter expansion for string manipulation
name=${line%%=*}
existing_value=${line#*=}
bind_port=${bind_port#*- }
bind_port=${bind_port#*\"}
bind_port=${bind_port%%:*}
```

### Here Documents
```bash
cat >&"${out}" <<END
$program_name ${SCRIPT_VERSION}, the QueryPie installation script.
Usage: $program_name [options]
    or $program_name [options] --install <version>
    or $program_name [options] --upgrade <version>
END
```

## Error Handling

### Exit Codes
```bash
function print_usage_and_exit() {
  local code=${1:-0} out=2 program_name=setup.v2.sh
  [[ code -eq 0 ]] && out=1
  # ... usage output ...
  exit "${code}"
}
```

### Error Functions
```bash
function log::error() {
  printf "%bERROR: %s%b\n" "$BOLD_RED" "$*" "$RESET" 1>&2
}

function log::warning() {
  printf "%bWARNING: %s%b\n" "$BOLD_YELLOW" "$*" "$RESET" 1>&2
}
```

### Command Failure Handling
```bash
function log::do() {
  printf "%b+ %s%b\n" "$BOLD_CYAN" "$*" "$RESET" 1>&2
  if "$@"; then
    return 0
  else
    log::error "Failed to run: $*"
    return 1
  fi
}
```

## Logging and Output

### Color Codes
```bash
BOLD_CYAN="\e[1;36m"
BOLD_YELLOW="\e[1;33m"
BOLD_RED="\e[1;91m"
RESET="\e[0m"
```

### Output Redirection
```bash
# Use stderr for status messages
echo >&2 "# Status message goes to stderr"

# Use stdout for data output
echo "${variable_value}"
```

### Progress Indicators
```bash
# Simple progress indicator with pipe processing
while IFS= read -r; do printf "." >&2; done
echo >&2 " Done."
```

## Command Execution

### Command Existence Check
```bash
function command_exists() {
  command -v "$@" >/dev/null 2>&1
}
```



### Subshell Execution
```bash
# Use subshells for isolated variable scope
( # Run in subshell, not to import variables into the current shell.
  . /etc/os-release
  echo "$ID" | tr '[:upper:]' '[:lower:]'
)
```

### Directory Operations
```bash
# Use pushd/popd for directory navigation
pushd "./directory/"
rm -f file
ln -s "${target}" link_name
popd
```





## File Operations

### Temporary Files
```bash
tmp_file=$(mktemp /tmp/env_file.XXXXXX)
# SC2064 Use single quotes, otherwise this expands now rather than when signaled.
#shellcheck disable=SC2064
trap "rm -f ${tmp_file}" EXIT
```

### File Reading
```bash
# Use file descriptors for reading
while IFS= read -r -u 9 line; do
  # Process line
done 9<"${source_file}" # 9 is unused file descriptor to read ${source_file}.

# Source environment files
if [[ -e config.env ]]; then
  # shellcheck disable=SC1091
  source config.env
fi
```

### File Permissions
```bash
log::do umask 0022 # Use 644 for files and 755 for directories by default
log::sudo install -m 755 docker-compose /usr/local/bin
```



## Comments and Documentation

### Section Headers
```bash
echo >&2 "#"
echo >&2 "## Configure sudo privileges"
echo >&2 "#"
```

### Inline Comments
```bash
local user
user="$(id -un 2>/dev/null || true)"  # Get current username
if [[ "${user}" == 'root' ]]; then
  echo >&2 "# The current user is 'root'. No need to use sudo."
  SUDO=() # No need to use sudo.
```

### Function Documentation
```bash
# /etc/os-release is provided by Linux Standard Base.
# https://refspecs.linuxfoundation.org/lsb.shtml
function lsb::id_like() {
  # Function implementation
}
```

## Best Practices

### Shell Options
```bash
# Ensure zsh compatibility
[[ -n "${ZSH_VERSION:-}" ]] && emulate bash
set -o nounset -o errexit -o pipefail
```

### Parameter Validation
```bash
function require::version() {
  local version=${1:-}

  if [[ -z "${version}" ]]; then
    log::error "Version is required. Please provide a version."
    print_usage_and_exit 1
  fi

  if [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return
  else
    log::warning "Unexpected version format: ${version}"
    install::ask_yes "Do you want to install this version? ${version}"
  fi
}
```

### User Interaction
```bash
function install::ask_yes() {
  echo "$@" >&2
  if [[ $ASSUME_YES == true ]]; then
    echo 'Do you agree? [y/N] :' 'yes'
    return
  elif [[ ! -t 0 ]]; then
    echo >&2 "# Standard input is not a terminal. Unable to receive user input."
    echo 'Do you agree? [y/N] :' 'no'
    return 1
  fi

  printf 'Do you agree? [y/N] : '
  local answer
  read -r answer # zsh compatibility: zsh does not support read -p prompt.
  case "${answer}" in
  y | Y | yes | YES | Yes) return ;;
  *) return 1 ;;
  esac
}
```

### Main Function Pattern
```bash
function main() {
  local -a arguments=() # argv is reserved for zsh.
  local cmd="install_recommended"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --yes)
      ASSUME_YES=true
      shift
      ;;
    # ... other options ...
    *)
      arguments+=("$1")
      shift
      ;;
    esac
  done

  # Execute command
  case "$cmd" in
  install_recommended)
    cmd::install_recommended
    ;;
  install)
    require::version "$@"
    cmd::install "$@"
    ;;
  # ... other commands ...
  esac
}

main "$@"
```

### Version Comparison
```bash
function upgrade::is_higher_version() {
  local current=$1 target=$2 higher
  higher=$(printf '%s\n%s' "$current" "$target" | sort -V | tail -n1)
  if [[ "$higher" == "$target" && "$target" != "$current" ]]; then
    return 0
  else
    return 1
  fi
}
```

## Shell Compatibility

### Zsh Compatibility
```bash
# Ensure zsh compatibility
[[ -n "${ZSH_VERSION:-}" ]] && emulate bash

# Use zsh-specific syntax when needed
if [[ -n "${ZSH_VERSION:-}" ]]; then
  # zsh: use (P) for indirect expansion
  # shellcheck disable=SC2296,SC2086
  if [[ ${(P)name+_} ]]; then
    print -r -- ${(P)name}
    return
  fi
else
  # bash: use indirect expansion
  if [[ -n "${!name+_}" ]]; then
    echo "${!name}"
    return
  fi
fi
```

### Cross-Platform Compatibility
```bash
# Handle different operating systems
if command -v command1 >/dev/null 2>&1; then
  result=$(command1)
elif [[ "$OSTYPE" == "darwin"* ]]; then
  result=$(command2)
else
  result=$(command3)
fi
```

This style guide ensures consistency, readability, and maintainability across bash scripts in the QueryPie project.

## Code Quality Tools

### ShellCheck Integration
```bash
# Disable specific shellcheck warnings when necessary
# shellcheck disable=SC2064
trap "rm -f ${tmp_file}" EXIT

# shellcheck disable=SC2296,SC2086
if [[ ${(P)name+_} ]]; then
  print -r -- ${(P)name}
  return
fi

# shellcheck disable=SC1091
source ../current/.env
```

### Common ShellCheck Disable Patterns
- `SC2064`: Used for trap commands with variable expansion
- `SC2296,SC2086`: Used for zsh-specific parameter expansion
- `SC1091`: Used when sourcing files that may not exist

### Linting Best Practices
- Only disable shellcheck warnings when absolutely necessary
- Provide clear comments explaining why the warning is disabled
- Use the most specific disable codes possible
- Consider alternative approaches before disabling warnings

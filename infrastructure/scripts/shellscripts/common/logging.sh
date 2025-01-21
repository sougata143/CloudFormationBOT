#!/bin/bash

# Log level constants
# Use regular variables instead of readonly
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_CRITICAL=4

# Logging configuration
PROJECT_ROOT="/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT"
LOG_DIR="${PROJECT_ROOT}/infrastructure/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Ensure log directory exists
mkdir -p "${LOG_DIR}/deployments"
mkdir -p "${LOG_DIR}/errors"

# Default log level
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Logging function with color and file logging
log() {
    local message="${1:?Message is required}"
    local log_level="${2:-INFO}"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Convert log level to uppercase
    log_level=$(echo "${log_level}" | tr '[:lower:]' '[:upper:]')
    
    # Determine numeric log level
    local numeric_level
    case "${log_level}" in
        DEBUG)    numeric_level=${LOG_LEVEL_DEBUG} ;;
        INFO)     numeric_level=${LOG_LEVEL_INFO} ;;
        WARN)     numeric_level=${LOG_LEVEL_WARN} ;;
        ERROR)    numeric_level=${LOG_LEVEL_ERROR} ;;
        CRITICAL) numeric_level=${LOG_LEVEL_CRITICAL} ;;
        *)        numeric_level=${LOG_LEVEL_INFO} ;;
    esac
    
    # Check if the log level is high enough to be displayed
    if [[ ${numeric_level} -ge ${CURRENT_LOG_LEVEL} ]]; then
        # Color coding for different log levels
        local color_reset='\033[0m'
        local color
        case "${log_level}" in
            DEBUG)   color='\033[34m'   ;; # Blue
            INFO)    color='\033[32m'   ;; # Green
            WARN)    color='\033[33m'   ;; # Yellow
            ERROR)   color='\033[31m'   ;; # Red
            CRITICAL) color='\033[1;31m' ;; # Bold Red
            *)       color='\033[0m'    ;; # Default
        esac
        
        # Console output with color
        echo -e "${color}[${timestamp}] [${log_level}] ${message}${color_reset}" >&2
    fi
    
    # File logging
    local log_file
    case "${log_level}" in
        DEBUG|INFO)
            log_file="${LOG_DIR}/deployments/deployment_${TIMESTAMP}.log"
            ;;
        WARN|ERROR|CRITICAL)
            log_file="${LOG_DIR}/errors/error_${TIMESTAMP}.log"
            ;;
        *)
            log_file="${LOG_DIR}/deployments/deployment_${TIMESTAMP}.log"
            ;;
    esac
    
    # Ensure log file exists and is writable
    touch "${log_file}"
    chmod 666 "${log_file}"
    
    # Log to file
    echo "[${timestamp}] [${log_level}] ${message}" >> "${log_file}"
}

# Function to set log level
set_log_level() {
    local level="${1:?Log level is required}"
    level=$(echo "${level}" | tr '[:lower:]' '[:upper:]')
    
    case "${level}" in
        DEBUG)    CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG} ;;
        INFO)     CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO} ;;
        WARN)     CURRENT_LOG_LEVEL=${LOG_LEVEL_WARN} ;;
        ERROR)    CURRENT_LOG_LEVEL=${LOG_LEVEL_ERROR} ;;
        CRITICAL) CURRENT_LOG_LEVEL=${LOG_LEVEL_CRITICAL} ;;
        *)
            log "Invalid log level: ${level}" "ERROR"
            return 1
            ;;
    esac
    
    log "Log level set to ${level}" "INFO"
    return 0
}

# Log stack events for CloudFormation
log_stack_events() {
    local stack_name="${1:?Stack name is required}"
    local region="${2:-us-east-1}"
    
    log "Retrieving stack events for ${stack_name}" "INFO"
    
    # Retrieve and log stack events
    local stack_events
    stack_events=$(aws cloudformation describe-stack-events \
        --stack-name "${stack_name}" \
        --region "${region}" \
        --query 'StackEvents[?contains(ResourceStatus, `FAILED`) || contains(ResourceStatus, `ROLLBACK`)]' \
        --output table 2>/dev/null)
    
    if [[ -n "${stack_events}" ]]; then
        log "Stack Events for ${stack_name}:" "ERROR"
        log "${stack_events}" "ERROR"
    else
        log "No failed events found for stack ${stack_name}" "INFO"
    fi
}

# Export functions and variables
export -f log
export -f set_log_level
export -f log_stack_events
export LOG_DIR
export TIMESTAMP
export CURRENT_LOG_LEVEL
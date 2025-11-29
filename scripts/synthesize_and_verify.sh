#!/bin/bash

################################################################################
# ADS Bus System - Automated Synthesis and Verification Script
# Target: Intel Cyclone V 5CSEBA6U23I7 (DE10-Nano)
# Date: October 14, 2025
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QUARTUS_DIR="$PROJECT_ROOT/quartus"
OUTPUT_DIR="$QUARTUS_DIR/output_files"
PROJECT_NAME="ads_bus_system"

# Counters
ERROR_COUNT=0
WARNING_COUNT=0
CRITICAL_WARNING_COUNT=0

################################################################################
# Utility Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((ERROR_COUNT++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNING_COUNT++))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 not found. Please install Quartus Prime."
        echo "Download: https://www.intel.com/content/www/us/en/software-kit/665990/intel-quartus-prime-lite-edition-design-software-version-20-1-for-linux.html"
        exit 1
    else
        print_success "$1 found: $(command -v $1)"
    fi
}

################################################################################
# Pre-Flight Checks
################################################################################

pre_flight_checks() {
    print_header "Pre-Flight Checks"
    
    # Check if Quartus is installed
    print_info "Checking for Quartus Prime installation..."
    check_command quartus_sh
    check_command quartus_map
    check_command quartus_fit
    check_command quartus_asm
    check_command quartus_sta
    
    # Check if project directory exists
    if [ ! -d "$QUARTUS_DIR" ]; then
        print_error "Quartus project directory not found: $QUARTUS_DIR"
        exit 1
    else
        print_success "Quartus project directory found"
    fi
    
    # Check if project files exist
    if [ ! -f "$QUARTUS_DIR/${PROJECT_NAME}.qpf" ]; then
        print_error "Project file not found: ${PROJECT_NAME}.qpf"
        exit 1
    else
        print_success "Project file found: ${PROJECT_NAME}.qpf"
    fi
    
    if [ ! -f "$QUARTUS_DIR/${PROJECT_NAME}.qsf" ]; then
        print_error "Settings file not found: ${PROJECT_NAME}.qsf"
        exit 1
    else
        print_success "Settings file found: ${PROJECT_NAME}.qsf"
    fi
    
    # Check RTL files
    print_info "Verifying RTL source files..."
    local rtl_files=0
    local missing_files=0
    
    while IFS= read -r line; do
        if [[ $line == *"VERILOG_FILE"* ]]; then
            ((rtl_files++))
            # Extract filename
            filename=$(echo "$line" | sed 's/.*VERILOG_FILE //' | tr -d '\r')
            # Convert relative path to absolute
            filepath="$QUARTUS_DIR/$filename"
            
            if [ -f "$filepath" ]; then
                echo "  ✓ $(basename $filename)"
            else
                print_error "  ✗ Missing: $filename"
                ((missing_files++))
            fi
        fi
    done < "$QUARTUS_DIR/${PROJECT_NAME}.qsf"
    
    print_success "Found $rtl_files RTL source files in .qsf"
    
    if [ $missing_files -gt 0 ]; then
        print_error "$missing_files RTL files are missing"
        exit 1
    fi
    
    # Check SDC file
    if [ ! -f "$PROJECT_ROOT/constraints/ads_bus_system.sdc" ]; then
        print_warning "SDC file not found (timing constraints may not be applied)"
    else
        print_success "SDC timing constraints file found"
    fi
    
    echo ""
    if [ $ERROR_COUNT -eq 0 ]; then
        print_success "All pre-flight checks passed"
    else
        print_error "$ERROR_COUNT pre-flight check(s) failed"
        exit 1
    fi
}

################################################################################
# Analysis & Synthesis Phase
################################################################################

run_synthesis() {
    print_header "Phase 1: Analysis & Synthesis"
    
    cd "$QUARTUS_DIR"
    
    print_info "Starting Analysis & Synthesis (quartus_map)..."
    print_info "This may take 1-2 minutes..."
    
    if quartus_map ${PROJECT_NAME} > ${PROJECT_NAME}_map.log 2>&1; then
        print_success "Analysis & Synthesis completed successfully"
    else
        print_error "Analysis & Synthesis failed"
        echo "Check log: $QUARTUS_DIR/${PROJECT_NAME}_map.log"
        tail -50 ${PROJECT_NAME}_map.log
        exit 1
    fi
    
    # Parse synthesis report
    print_info "Analyzing synthesis results..."
    
    if [ -f "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" ]; then
        # Check for errors
        local errors=$(grep -c "Error" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" || true)
        local crit_warnings=$(grep -c "Critical Warning" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" || true)
        local warnings=$(grep -c "Warning" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" || true)
        
        if [ $errors -gt 0 ]; then
            print_error "Found $errors error(s) in synthesis"
            ERROR_COUNT=$((ERROR_COUNT + errors))
        else
            print_success "0 errors in synthesis"
        fi
        
        if [ $crit_warnings -gt 0 ]; then
            print_warning "Found $crit_warnings critical warning(s)"
            CRITICAL_WARNING_COUNT=$((CRITICAL_WARNING_COUNT + crit_warnings))
        else
            print_success "0 critical warnings"
        fi
        
        print_info "$warnings warning(s) found"
        
        # Check for memory inference
        local m10k_count=$(grep -c "M10K" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" || true)
        if [ $m10k_count -gt 0 ]; then
            print_success "M10K memory blocks inferred successfully"
            grep "M10K" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" | head -5
        else
            print_warning "No M10K blocks found (expected 10 blocks for 3 slaves)"
        fi
        
        # Resource usage estimation
        echo ""
        print_info "Resource Usage (Estimate):"
        grep -A 10 "Fitter Resource Usage Summary" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" || \
        grep -A 10 "Analysis & Synthesis Resource Usage Summary" "$OUTPUT_DIR/${PROJECT_NAME}.map.rpt" || \
        print_info "Resource summary not available in synthesis report"
        
    else
        print_error "Synthesis report not found"
        exit 1
    fi
}

################################################################################
# Fitter Phase
################################################################################

run_fitter() {
    print_header "Phase 2: Fitter (Place & Route)"
    
    cd "$QUARTUS_DIR"
    
    print_info "Starting Fitter (quartus_fit)..."
    print_info "This may take 2-3 minutes..."
    
    if quartus_fit ${PROJECT_NAME} > ${PROJECT_NAME}_fit.log 2>&1; then
        print_success "Fitter completed successfully"
    else
        print_error "Fitter failed"
        echo "Check log: $QUARTUS_DIR/${PROJECT_NAME}_fit.log"
        tail -50 ${PROJECT_NAME}_fit.log
        exit 1
    fi
    
    # Parse fitter report
    print_info "Analyzing fitter results..."
    
    if [ -f "$OUTPUT_DIR/${PROJECT_NAME}.fit.rpt" ]; then
        # Check for errors
        local errors=$(grep -c "Error" "$OUTPUT_DIR/${PROJECT_NAME}.fit.rpt" || true)
        local crit_warnings=$(grep -c "Critical Warning" "$OUTPUT_DIR/${PROJECT_NAME}.fit.rpt" || true)
        
        if [ $errors -gt 0 ]; then
            print_error "Found $errors error(s) in fitter"
            ERROR_COUNT=$((ERROR_COUNT + errors))
        else
            print_success "0 errors in fitter"
        fi
        
        if [ $crit_warnings -gt 0 ]; then
            print_warning "Found $crit_warnings critical warning(s)"
            CRITICAL_WARNING_COUNT=$((CRITICAL_WARNING_COUNT + crit_warnings))
        fi
        
        # Resource utilization
        echo ""
        print_info "Final Resource Utilization:"
        grep -A 15 "Fitter Resource Usage Summary" "$OUTPUT_DIR/${PROJECT_NAME}.fit.rpt" | head -20
        
        # Check if within target (<50%)
        local alm_usage=$(grep "ALMs" "$OUTPUT_DIR/${PROJECT_NAME}.fit.rpt" | head -1 | awk '{print $3}' | tr -d '%' || echo "0")
        if [ -n "$alm_usage" ] && [ "$alm_usage" -lt 50 ]; then
            print_success "Resource utilization within target (<50%): ${alm_usage}%"
        elif [ -n "$alm_usage" ]; then
            print_warning "Resource utilization: ${alm_usage}%"
        fi
        
        # Pin assignments
        echo ""
        print_info "Verifying pin assignments..."
        local assigned_pins=$(grep -c "Pin Name" "$OUTPUT_DIR/${PROJECT_NAME}.pin" || true)
        print_info "Total pins assigned: $assigned_pins (expected: 27)"
        
    else
        print_error "Fitter report not found"
        exit 1
    fi
}

################################################################################
# Assembler Phase
################################################################################

run_assembler() {
    print_header "Phase 3: Assembler (Generate Programming File)"
    
    cd "$QUARTUS_DIR"
    
    print_info "Starting Assembler (quartus_asm)..."
    
    if quartus_asm ${PROJECT_NAME} > ${PROJECT_NAME}_asm.log 2>&1; then
        print_success "Assembler completed successfully"
    else
        print_error "Assembler failed"
        echo "Check log: $QUARTUS_DIR/${PROJECT_NAME}_asm.log"
        tail -50 ${PROJECT_NAME}_asm.log
        exit 1
    fi
    
    # Check if .sof file was generated
    if [ -f "$OUTPUT_DIR/${PROJECT_NAME}.sof" ]; then
        local sof_size=$(ls -lh "$OUTPUT_DIR/${PROJECT_NAME}.sof" | awk '{print $5}')
        print_success "Programming file generated: ${PROJECT_NAME}.sof ($sof_size)"
        print_info "Location: $OUTPUT_DIR/${PROJECT_NAME}.sof"
    else
        print_error "Programming file (.sof) not generated"
        exit 1
    fi
}

################################################################################
# Timing Analysis Phase
################################################################################

run_timing_analysis() {
    print_header "Phase 4: Timing Analysis"
    
    cd "$QUARTUS_DIR"
    
    print_info "Starting Timing Analyzer (quartus_sta)..."
    
    if quartus_sta ${PROJECT_NAME} > ${PROJECT_NAME}_sta.log 2>&1; then
        print_success "Timing analysis completed successfully"
    else
        print_error "Timing analysis failed"
        echo "Check log: $QUARTUS_DIR/${PROJECT_NAME}_sta.log"
        tail -50 ${PROJECT_NAME}_sta.log
        exit 1
    fi
    
    # Parse timing report
    print_info "Analyzing timing results..."
    
    if [ -f "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" ]; then
        echo ""
        print_info "Fmax Summary:"
        grep -A 10 "Slow 1200mV 100C Model Fmax Summary" "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" | head -15 || \
        grep -A 5 "Fmax" "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" | head -10 || \
        print_info "Fmax summary not found in standard format"
        
        echo ""
        print_info "Setup Summary:"
        grep -A 10 "Setup Summary" "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" | head -15 || \
        print_info "Setup summary not found"
        
        echo ""
        print_info "Hold Summary:"
        grep -A 10 "Hold Summary" "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" | head -15 || \
        print_info "Hold summary not found"
        
        # Check for timing violations
        local timing_errors=$(grep -c "Timing requirements not met" "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" || true)
        if [ $timing_errors -gt 0 ]; then
            print_error "Timing requirements NOT MET"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        else
            print_success "All timing requirements MET"
        fi
        
        # Check slack
        local setup_slack=$(grep "slack" "$OUTPUT_DIR/${PROJECT_NAME}.sta.rpt" | head -1 || echo "")
        if [ -n "$setup_slack" ]; then
            print_info "Setup slack: $setup_slack"
        fi
        
    else
        print_error "Timing analysis report not found"
        exit 1
    fi
}

################################################################################
# Summary Report
################################################################################

generate_summary() {
    print_header "Synthesis Summary Report"
    
    echo ""
    echo "Project: $PROJECT_NAME"
    echo "Target Device: Intel Cyclone V 5CSEBA6U23I7 (DE10-Nano)"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    print_info "Compilation Phases:"
    echo "  ✓ Analysis & Synthesis"
    echo "  ✓ Fitter (Place & Route)"
    echo "  ✓ Assembler (Generate .sof)"
    echo "  ✓ Timing Analysis"
    echo ""
    
    print_info "Output Files:"
    if [ -f "$OUTPUT_DIR/${PROJECT_NAME}.sof" ]; then
        echo "  ✓ ${PROJECT_NAME}.sof ($(ls -lh $OUTPUT_DIR/${PROJECT_NAME}.sof | awk '{print $5}'))"
    fi
    echo "  ✓ ${PROJECT_NAME}.map.rpt"
    echo "  ✓ ${PROJECT_NAME}.fit.rpt"
    echo "  ✓ ${PROJECT_NAME}.sta.rpt"
    echo ""
    
    print_info "Status Summary:"
    echo "  Errors: $ERROR_COUNT"
    echo "  Critical Warnings: $CRITICAL_WARNING_COUNT"
    echo "  Warnings: $WARNING_COUNT"
    echo ""
    
    if [ $ERROR_COUNT -eq 0 ]; then
        print_success "========================================="
        print_success "  SYNTHESIS COMPLETED SUCCESSFULLY!"
        print_success "========================================="
        echo ""
        print_info "Next Steps:"
        echo "  1. Program FPGA: quartus_pgm -m jtag -o \"p;$OUTPUT_DIR/${PROJECT_NAME}.sof@1\""
        echo "  2. Verify LED[0] turns ON after programming"
        echo "  3. Connect external masters to GPIO pins"
        echo "  4. Refer to docs/ADS_Bus_System_Documentation.md for usage"
        echo ""
        return 0
    else
        print_error "========================================="
        print_error "  SYNTHESIS FAILED ($ERROR_COUNT errors)"
        print_error "========================================="
        echo ""
        print_info "Check logs in: $QUARTUS_DIR/"
        echo "  - ${PROJECT_NAME}_map.log"
        echo "  - ${PROJECT_NAME}_fit.log"
        echo "  - ${PROJECT_NAME}_asm.log"
        echo "  - ${PROJECT_NAME}_sta.log"
        echo ""
        print_info "Reports in: $OUTPUT_DIR/"
        echo "  - ${PROJECT_NAME}.map.rpt"
        echo "  - ${PROJECT_NAME}.fit.rpt"
        echo "  - ${PROJECT_NAME}.sta.rpt"
        echo ""
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "ADS Bus System - Quartus Prime Synthesis"
    echo "Target: Intel Cyclone V 5CSEBA6U23I7 (Terasic DE10-Nano)"
    echo "Project: $PROJECT_NAME"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Parse command line arguments
    SKIP_CHECKS=false
    PHASE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            --phase)
                PHASE="$2"
                shift 2
                ;;
            --help)
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-checks       Skip pre-flight checks"
                echo "  --phase <phase>     Run specific phase only (map|fit|asm|sta)"
                echo "  --help              Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                  # Run full compilation flow"
                echo "  $0 --phase map      # Run synthesis only"
                echo "  $0 --phase sta      # Run timing analysis only"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute phases
    if [ "$SKIP_CHECKS" = false ]; then
        pre_flight_checks
    fi
    
    if [ -z "$PHASE" ] || [ "$PHASE" = "map" ]; then
        run_synthesis
    fi
    
    if [ -z "$PHASE" ] || [ "$PHASE" = "fit" ]; then
        run_fitter
    fi
    
    if [ -z "$PHASE" ] || [ "$PHASE" = "asm" ]; then
        run_assembler
    fi
    
    if [ -z "$PHASE" ] || [ "$PHASE" = "sta" ]; then
        run_timing_analysis
    fi
    
    # Generate summary
    generate_summary
    exit $?
}

# Run main function
main "$@"

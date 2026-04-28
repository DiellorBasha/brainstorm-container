#!/bin/bash
# =============================================================================
# Brainstorm BIDS App — MCR Entrypoint (Version B: Self-Contained)
# =============================================================================
# Same BIDS App CLI as Version A, but uses compiled standalone + MCR
# instead of requiring host MATLAB.
#
# The container bundles:
#   - Compiled bst_single_subject_standalone + bst_aggregate_subjects_standalone
#   - MATLAB Compiler Runtime R2023b
#   - Brainstorm source tree (for template data like ICBM152)
#
# No external dependencies required — truly portable.
#
# Modes:
#   participant  — Run per-subject pipeline
#   aggregate    — Combine per-subject .zip exports into a group protocol
# =============================================================================

set -euo pipefail

# ─── Paths ───────────────────────────────────────────────────────────────────
MCR_ROOT="${MCR_ROOT:-/opt/mcr/R2023b}"
COMPILED_DIR="${COMPILED_DIR:-/opt/brainstorm-pipeline/compiled}"
BST_DIR="${BST_DIR:-/opt/brainstorm3}"
PIPELINE_DIR="${PIPELINE_DIR:-/opt/brainstorm-pipeline}"

# ─── Usage ───────────────────────────────────────────────────────────────────
usage() {
    cat << 'EOF'
Brainstorm BIDS App — MCR Version (Self-Contained)

USAGE:
  brainstorm-pipeline <bids_dir> <output_dir> participant [OPTIONS]
  brainstorm-pipeline aggregate [OPTIONS]

PARTICIPANT MODE (per-subject processing):
  Positional:
    bids_dir       Path to BIDS dataset root (read-only)
    output_dir     Path for pipeline outputs (.zip exports, logs)
    participant    Analysis level (required literal)

  Required:
    --participant-label LABEL   Subject label without 'sub-' prefix (e.g., 0002)
    --module MODULE             Pipeline stop position: import|preprocess|source|timefreq

  Optional:
    --nvertices N               Cortex downsampling vertices (default: 15000)
    --bst-db-dir PATH           Throwaway protocol DB location (default: /tmp/brainstorm_db)

AGGREGATE MODE (combine per-subject exports):
  Required:
    --zip-dir PATH              Directory containing sub-*_brainstorm.zip files
    --protocol-name NAME        Name for the group protocol

  Optional:
    --output-zip PATH           Export group protocol to this .zip
    --bst-db-dir PATH           Protocol database location

NOTES:
  This is the MCR (self-contained) version. No external MATLAB required.
  The compiled standalone + MCR R2023b are bundled in the container.

EXAMPLES:
  # Full pipeline for one subject
  apptainer run brainstorm-pipeline-mcr.sif \
      /data/omega /output participant \
      --participant-label 0002 --module timefreq

  # Aggregate
  apptainer run brainstorm-pipeline-mcr.sif \
      aggregate --zip-dir /output --protocol-name OMEGA_Group
EOF
}

# ─── Start virtual framebuffer ───────────────────────────────────────────────
start_xvfb() {
    if ! pgrep -x Xvfb &>/dev/null; then
        Xvfb :99 -screen 0 1024x768x24 &>/dev/null &
        export DISPLAY=:99
        sleep 1
    fi
}

# ─── Run compiled standalone ────────────────────────────────────────────────
run_standalone() {
    local binary="$1"
    shift
    start_xvfb

    echo "─── Running: ${binary} ───"
    echo "Arguments: $@"
    echo "MCR_ROOT: ${MCR_ROOT}"
    echo "───────────────────────────"

    # The compiled standalone uses the MCR. The run_*.sh wrapper sets
    # LD_LIBRARY_PATH and calls the binary. We replicate that inline:
    export LD_LIBRARY_PATH="${MCR_ROOT}/runtime/glnxa64:${MCR_ROOT}/bin/glnxa64:${MCR_ROOT}/sys/os/glnxa64:${MCR_ROOT}/extern/bin/glnxa64:${MCR_ROOT}/sys/opengl/lib/glnxa64:${LD_LIBRARY_PATH:-}"
    export XAPPLRESDIR="${MCR_ROOT}/X11/app-defaults"
    export MCR_CACHE_ROOT="${MCR_CACHE_ROOT:-/tmp/mcr_cache_$$}"
    mkdir -p "${MCR_CACHE_ROOT}"

    "${binary}" "$@"
    local exit_code=$?

    # Cleanup MCR cache
    rm -rf "${MCR_CACHE_ROOT}" 2>/dev/null || true
    return $exit_code
}

# ─── Participant mode ────────────────────────────────────────────────────────
run_participant() {
    local bids_dir="$1"
    local output_dir="$2"
    shift 2  # remove bids_dir and output_dir
    shift    # remove 'participant'

    # Parse options
    local participant_label=""
    local module=""
    local nvertices=15000
    local bst_db_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --participant-label) participant_label="$2"; shift 2 ;;
            --module)            module="$2"; shift 2 ;;
            --nvertices)         nvertices="$2"; shift 2 ;;
            --bst-db-dir)        bst_db_dir="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$participant_label" ]]; then
        echo "ERROR: --participant-label is required"
        usage
        exit 1
    fi
    if [[ -z "$module" ]]; then
        echo "ERROR: --module is required (import|preprocess|source|timefreq)"
        usage
        exit 1
    fi
    if [[ ! "$module" =~ ^(import|preprocess|source|timefreq)$ ]]; then
        echo "ERROR: --module must be one of: import, preprocess, source, timefreq"
        exit 1
    fi

    # Resolve bst_db_dir
    if [[ -z "$bst_db_dir" ]]; then
        if [[ -n "${SLURM_TMPDIR:-}" ]]; then
            bst_db_dir="${SLURM_TMPDIR}/brainstorm_db"
        else
            bst_db_dir="/tmp/brainstorm_db"
        fi
    fi

    # Ensure output directory exists
    mkdir -p "$output_dir" 2>/dev/null || true

    echo "═══════════════════════════════════════════════════════════════════"
    echo " Brainstorm BIDS App — MCR Version (Participant Mode)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Subject:     sub-${participant_label}"
    echo " Module:      ${module}"
    echo " BIDS dir:    ${bids_dir}"
    echo " Output dir:  ${output_dir}"
    echo " BstDir:      ${BST_DIR}"
    echo " BstDbDir:    ${bst_db_dir}"
    echo " NVertices:   ${nvertices}"
    echo " MCR:         ${MCR_ROOT}"
    echo "═══════════════════════════════════════════════════════════════════"

    local binary="${COMPILED_DIR}/bst_single_subject_standalone"
    if [[ ! -x "$binary" ]]; then
        echo "ERROR: Compiled binary not found: $binary"
        exit 1
    fi

    # Compiled MATLAB functions receive all args as strings
    run_standalone "$binary" \
        "$bids_dir" \
        "$output_dir" \
        "$participant_label" \
        "$module" \
        "BstDir" "${BST_DIR}" \
        "BstDbDir" "${bst_db_dir}" \
        "NVertices" "${nvertices}"

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo ""
        echo "Pipeline completed successfully for sub-${participant_label}."
        echo "Output: ${output_dir}/sub-${participant_label}_brainstorm.zip"
    else
        echo ""
        echo "ERROR: Pipeline failed for sub-${participant_label} (exit code: ${exit_code})"
        exit $exit_code
    fi
}

# ─── Aggregate mode ──────────────────────────────────────────────────────────
run_aggregate() {
    shift  # remove 'aggregate'

    local zip_dir=""
    local protocol_name=""
    local output_zip=""
    local bst_db_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --zip-dir)         zip_dir="$2"; shift 2 ;;
            --protocol-name)   protocol_name="$2"; shift 2 ;;
            --output-zip)      output_zip="$2"; shift 2 ;;
            --bst-db-dir)      bst_db_dir="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    # Validate
    if [[ -z "$zip_dir" ]]; then
        echo "ERROR: --zip-dir is required for aggregate mode"
        exit 1
    fi
    if [[ -z "$protocol_name" ]]; then
        echo "ERROR: --protocol-name is required for aggregate mode"
        exit 1
    fi

    if [[ -z "$bst_db_dir" ]]; then
        if [[ -n "${SLURM_TMPDIR:-}" ]]; then
            bst_db_dir="${SLURM_TMPDIR}/brainstorm_db"
        else
            bst_db_dir="/tmp/brainstorm_db"
        fi
    fi

    echo "═══════════════════════════════════════════════════════════════════"
    echo " Brainstorm BIDS App — MCR Version (Aggregate Mode)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Zip dir:       ${zip_dir}"
    echo " Protocol:      ${protocol_name}"
    echo " Output zip:    ${output_zip:-<none>}"
    echo " BstDir:        ${BST_DIR}"
    echo " BstDbDir:      ${bst_db_dir}"
    echo " MCR:           ${MCR_ROOT}"
    echo "═══════════════════════════════════════════════════════════════════"

    local binary="${COMPILED_DIR}/bst_aggregate_subjects_standalone"
    if [[ ! -x "$binary" ]]; then
        echo "ERROR: Compiled binary not found: $binary"
        exit 1
    fi

    # Build argument list
    local args=("$zip_dir" "$protocol_name" "BstDir" "${BST_DIR}" "BstDbDir" "${bst_db_dir}")
    if [[ -n "$output_zip" ]]; then
        args+=("OutputZip" "$output_zip")
    fi

    run_standalone "$binary" "${args[@]}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo ""
        echo "Aggregation completed: ${protocol_name}"
    else
        echo "ERROR: Aggregation failed (exit code: ${exit_code})"
        exit $exit_code
    fi
}

# ─── Main dispatch ───────────────────────────────────────────────────────────
main() {
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
        exit 0
    fi

    # Verify MCR exists
    if [[ ! -d "${MCR_ROOT}" ]]; then
        echo "ERROR: MCR not found at ${MCR_ROOT}"
        echo "This container may be corrupt or improperly built."
        exit 1
    fi

    # Dispatch based on mode
    if [[ "$1" == "aggregate" ]]; then
        run_aggregate "$@"
    elif [[ $# -ge 3 ]] && [[ "$3" == "participant" ]]; then
        run_participant "$@"
    else
        echo "ERROR: Unrecognized command. Expected 'participant' or 'aggregate' mode."
        echo ""
        usage
        exit 1
    fi
}

main "$@"

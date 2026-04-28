#!/bin/bash
# =============================================================================
# Brainstorm BIDS App — Entrypoint
# =============================================================================
# Implements the BIDS App CLI standard for single-subject MEG/EEG processing.
#
# Modes:
#   participant  — Run per-subject pipeline (import → preprocess → source → timefreq)
#   aggregate    — Combine per-subject .zip exports into a group protocol
#
# Requires MATLAB on the host (Alliance: module load matlab/2023b.2).
# Brainstorm source tree is bundled in the container at /opt/brainstorm3.
#
# References:
#   - BIDS Apps: https://bids-apps.neuroimaging.io/
#   - Brainstorm scripting: https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting
# =============================================================================

set -euo pipefail

# ─── Paths ───────────────────────────────────────────────────────────────────
BST_DIR="${BST_DIR:-/opt/brainstorm3}"
PIPELINE_DIR="${PIPELINE_DIR:-/opt/brainstorm-pipeline}"
SCRIPTS_DIR="${PIPELINE_DIR}/scripts"

# ─── Usage ───────────────────────────────────────────────────────────────────
usage() {
    cat << 'EOF'
Brainstorm BIDS App — MEG/EEG Pipeline

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
    --bst-db-dir PATH           Throwaway protocol DB location (default: $SLURM_TMPDIR/brainstorm_db or /tmp/brainstorm_db)
    --bst-dir PATH              Override Brainstorm source tree (default: /opt/brainstorm3)

AGGREGATE MODE (combine per-subject exports):
  Required:
    --zip-dir PATH              Directory containing sub-*_brainstorm.zip files
    --protocol-name NAME        Name for the group protocol

  Optional:
    --output-zip PATH           Export group protocol to this .zip
    --bst-db-dir PATH           Protocol database location

EXAMPLES:
  # Full pipeline for one subject
  apptainer run brainstorm-pipeline.sif \
      /data/omega /output participant \
      --participant-label 0002 --module timefreq

  # Import only
  apptainer run brainstorm-pipeline.sif \
      /data/omega /output participant \
      --participant-label 0002 --module import

  # Aggregate
  apptainer run brainstorm-pipeline.sif \
      aggregate --zip-dir /output --protocol-name OMEGA_Group

  # SLURM array job (subject label from SLURM_ARRAY_TASK_ID)
  apptainer run brainstorm-pipeline.sif \
      /data/omega /output participant \
      --participant-label ${SUBJECTS[$SLURM_ARRAY_TASK_ID]} --module timefreq
EOF
}

# ─── Detect MATLAB ───────────────────────────────────────────────────────────
find_matlab() {
    # Check if matlab is already in PATH (from module load)
    if command -v matlab &>/dev/null; then
        MATLAB_BIN=$(command -v matlab)
        echo "Found MATLAB: ${MATLAB_BIN}"
        return 0
    fi

    # Check common Alliance paths
    local search_paths=(
        "/cvmfs/restricted.computecanada.ca/easybuild/software/2023/x86-64-v3/Core/matlab/2023b.2/bin/matlab"
        "/usr/local/MATLAB/R2023b/bin/matlab"
        "/opt/matlab/R2023b/bin/matlab"
    )
    for p in "${search_paths[@]}"; do
        if [[ -x "$p" ]]; then
            MATLAB_BIN="$p"
            echo "Found MATLAB at: ${MATLAB_BIN}"
            return 0
        fi
    done

    echo "ERROR: MATLAB not found. On Alliance HPC, run:"
    echo "  module load matlab/2023b.2"
    echo "before invoking the container."
    return 1
}

# ─── Start virtual framebuffer ───────────────────────────────────────────────
start_xvfb() {
    if ! pgrep -x Xvfb &>/dev/null; then
        Xvfb :99 -screen 0 1024x768x24 &>/dev/null &
        export DISPLAY=:99
        sleep 1
    fi
}

# ─── Build MATLAB command ────────────────────────────────────────────────────
run_matlab() {
    local matlab_code="$1"
    start_xvfb
    echo "─── MATLAB command ───"
    echo "$matlab_code"
    echo "───────────────────────"

    "${MATLAB_BIN}" -nodisplay -nosplash -nodesktop -batch "$matlab_code"
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
    local bst_dir_override=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --participant-label) participant_label="$2"; shift 2 ;;
            --module)            module="$2"; shift 2 ;;
            --nvertices)         nvertices="$2"; shift 2 ;;
            --bst-db-dir)        bst_db_dir="$2"; shift 2 ;;
            --bst-dir)           bst_dir_override="$2"; shift 2 ;;
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

    # Resolve paths
    local use_bst_dir="${bst_dir_override:-${BST_DIR}}"

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
    echo " Brainstorm BIDS App — Participant Mode"
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Subject:     sub-${participant_label}"
    echo " Module:      ${module}"
    echo " BIDS dir:    ${bids_dir}"
    echo " Output dir:  ${output_dir}"
    echo " BstDir:      ${use_bst_dir}"
    echo " BstDbDir:    ${bst_db_dir}"
    echo " NVertices:   ${nvertices}"
    echo "═══════════════════════════════════════════════════════════════════"

    # Build MATLAB command
    local matlab_code="
addpath('${use_bst_dir}');
addpath('${SCRIPTS_DIR}');
bst_single_subject('${bids_dir}', '${output_dir}', '${participant_label}', '${module}', ...
    'BstDir', '${use_bst_dir}', ...
    'BstDbDir', '${bst_db_dir}', ...
    'NVertices', ${nvertices});
exit(0);
"
    run_matlab "$matlab_code"
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
    local bst_dir_override=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --zip-dir)         zip_dir="$2"; shift 2 ;;
            --protocol-name)   protocol_name="$2"; shift 2 ;;
            --output-zip)      output_zip="$2"; shift 2 ;;
            --bst-db-dir)      bst_db_dir="$2"; shift 2 ;;
            --bst-dir)         bst_dir_override="$2"; shift 2 ;;
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

    local use_bst_dir="${bst_dir_override:-${BST_DIR}}"

    if [[ -z "$bst_db_dir" ]]; then
        if [[ -n "${SLURM_TMPDIR:-}" ]]; then
            bst_db_dir="${SLURM_TMPDIR}/brainstorm_db"
        else
            bst_db_dir="/tmp/brainstorm_db"
        fi
    fi

    echo "═══════════════════════════════════════════════════════════════════"
    echo " Brainstorm BIDS App — Aggregate Mode"
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Zip dir:       ${zip_dir}"
    echo " Protocol:      ${protocol_name}"
    echo " Output zip:    ${output_zip:-<none>}"
    echo " BstDir:        ${use_bst_dir}"
    echo " BstDbDir:      ${bst_db_dir}"
    echo "═══════════════════════════════════════════════════════════════════"

    # Build MATLAB command
    local output_arg=""
    if [[ -n "$output_zip" ]]; then
        output_arg="'OutputZip', '${output_zip}', "
    fi

    local matlab_code="
addpath('${use_bst_dir}');
addpath('${SCRIPTS_DIR}');
bst_aggregate_subjects('${zip_dir}', '${protocol_name}', ...
    'BstDir', '${use_bst_dir}', ...
    'BstDbDir', '${bst_db_dir}', ...
    ${output_arg});
exit(0);
"
    run_matlab "$matlab_code"
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

    # Find MATLAB before doing anything else
    find_matlab || exit 1

    # Dispatch based on mode
    # BIDS App: <bids_dir> <output_dir> participant ...
    # Aggregate: aggregate ...
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

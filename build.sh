#!/bin/bash
# =============================================================================
# Build the Brainstorm Pipeline Apptainer container
# =============================================================================
# Run this on fir (Alliance HPC) where Apptainer is available.
#
# Usage:
#   ssh fir
#   cd ~/workspace/software/brainstorm-container
#   ./build.sh
#
# Output:
#   brainstorm-pipeline.sif (~2-3 GB)
#
# Requirements:
#   - Apptainer (available on Alliance via module or system install)
#   - Internet access (for git clone during build) — use a login node
#   - ~10 GB temporary disk space during build
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIF_NAME="brainstorm-pipeline.sif"
DEF_FILE="${SCRIPT_DIR}/brainstorm-pipeline.def"
OUTPUT="${SCRIPT_DIR}/${SIF_NAME}"

echo "═══════════════════════════════════════════════════════════════════"
echo " Building Brainstorm Pipeline Container"
echo "═══════════════════════════════════════════════════════════════════"
echo " Definition: ${DEF_FILE}"
echo " Output:     ${OUTPUT}"
echo " Started:    $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# Check Apptainer is available
if ! command -v apptainer &>/dev/null; then
    echo "ERROR: apptainer not found. On Alliance, try:"
    echo "  module load apptainer"
    exit 1
fi

# Check definition file exists
if [[ ! -f "$DEF_FILE" ]]; then
    echo "ERROR: Definition file not found: $DEF_FILE"
    exit 1
fi

# Build with --fakeroot (no sudo needed on Alliance)
echo ""
echo "Building container (this takes 5-15 minutes)..."
echo ""

# Use APPTAINER_TMPDIR on scratch for large temp files
export APPTAINER_TMPDIR="${SCRATCH:-/tmp}/apptainer_tmp_$$"
mkdir -p "${APPTAINER_TMPDIR}"

apptainer build --fakeroot "${OUTPUT}" "${DEF_FILE}"
BUILD_EXIT=$?

# Cleanup temp
rm -rf "${APPTAINER_TMPDIR}"

if [[ $BUILD_EXIT -eq 0 ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Build successful!"
    echo " Container: ${OUTPUT}"
    echo " Size: $(du -h "${OUTPUT}" | cut -f1)"
    echo " Finished: $(date)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo "  1. Copy to shared location:"
    echo "     cp ${OUTPUT} /project/rrg-baillet-ab/dbasha/workspace/software/containers/"
    echo ""
    echo "  2. Test with a single subject:"
    echo "     module load matlab/2023b.2"
    echo "     apptainer run --bind /project/rrg-baillet-ab/databank/datasets/omega-tutorial:/data:ro \\"
    echo "         --bind /scratch/\$USER/test_output:/output \\"
    echo "         ${OUTPUT} /data /output participant \\"
    echo "         --participant-label 0002 --module import"
    echo ""
    echo "  3. Submit full pipeline:"
    echo "     ./slurm/submit_pipeline.sh 0-1"
else
    echo ""
    echo "ERROR: Build failed (exit code: ${BUILD_EXIT})"
    exit $BUILD_EXIT
fi

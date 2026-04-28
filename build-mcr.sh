#!/bin/bash
# =============================================================================
# Build the Brainstorm Pipeline MCR Container (Version B: Self-Contained)
# =============================================================================
# Two-phase build:
#   Phase 1: Compile MATLAB scripts into standalone binaries (requires MATLAB)
#   Phase 2: Build Apptainer container with compiled binaries + MCR
#
# Run this on fir (Alliance HPC) where both MATLAB and Apptainer are available.
#
# Usage:
#   ssh fir
#   cd ~/workspace/software/brainstorm-container
#   ./build-mcr.sh
#
# Prerequisites:
#   1. Download MCR R2023b for Linux x64 and place in staging/compiled/:
#      https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/2/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_Update_2_glnxa64.zip
#
#      wget -O staging/compiled/MATLAB_Runtime_R2023b_glnxa64.zip \
#          "https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/2/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_Update_2_glnxa64.zip"
#
#   2. MATLAB with Compiler toolbox available (module load matlab/2023b.2)
#
# Output:
#   brainstorm-pipeline-mcr.sif (~2-4 GB)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIF_NAME="brainstorm-pipeline-mcr.sif"
DEF_FILE="${SCRIPT_DIR}/brainstorm-pipeline-mcr.def"
OUTPUT="${SCRIPT_DIR}/${SIF_NAME}"
STAGING_DIR="${SCRIPT_DIR}/staging/compiled"
BST_DIR="${BST_DIR:-$HOME/workspace/software/brainstorm3}"

echo "═══════════════════════════════════════════════════════════════════"
echo " Building Brainstorm Pipeline MCR Container (Version B)"
echo "═══════════════════════════════════════════════════════════════════"
echo " Definition: ${DEF_FILE}"
echo " Output:     ${OUTPUT}"
echo " Staging:    ${STAGING_DIR}"
echo " BstDir:     ${BST_DIR}"
echo " Started:    $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# ─── Phase 0: Validate prerequisites ────────────────────────────────────────
echo ""
echo "Phase 0: Validating prerequisites..."

# Check Apptainer
if ! command -v apptainer &>/dev/null; then
    echo "ERROR: apptainer not found. On Alliance, try: module load apptainer"
    exit 1
fi

# Check definition file
if [[ ! -f "$DEF_FILE" ]]; then
    echo "ERROR: Definition file not found: $DEF_FILE"
    exit 1
fi

# Check Brainstorm source tree
if [[ ! -f "${BST_DIR}/brainstorm.m" ]]; then
    echo "ERROR: Brainstorm source tree not found at: ${BST_DIR}"
    echo "Set BST_DIR environment variable or ensure ~/workspace/software/brainstorm3 exists"
    exit 1
fi

# Check MCR zip
MCR_ZIP="${STAGING_DIR}/MATLAB_Runtime_R2023b_glnxa64.zip"
if [[ ! -f "$MCR_ZIP" ]]; then
    echo ""
    echo "WARNING: MCR zip not found at: ${MCR_ZIP}"
    echo ""
    echo "Download it first:"
    echo "  mkdir -p ${STAGING_DIR}"
    echo "  wget -O ${MCR_ZIP} \\"
    echo "    'https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/2/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_Update_2_glnxa64.zip'"
    echo ""
    echo "Or if wget is blocked, download on a machine with internet access and scp to fir."
    echo ""
    read -p "Continue without MCR zip? (compilation only) [y/N]: " REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        exit 1
    fi
    SKIP_BUILD=true
else
    echo "  MCR zip found: $(du -h "$MCR_ZIP" | cut -f1)"
    SKIP_BUILD=false
fi

# ─── Phase 1: Compile standalone binaries ────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo " Phase 1: Compiling MATLAB scripts into standalone binaries"
echo "═══════════════════════════════════════════════════════════════════"

# Load MATLAB module (Alliance)
if command -v module &>/dev/null; then
    module load matlab/2023b.2 2>/dev/null || true
fi

# Verify MATLAB is available
if ! command -v matlab &>/dev/null; then
    echo "ERROR: MATLAB not found. On Alliance: module load matlab/2023b.2"
    exit 1
fi

echo "  MATLAB: $(which matlab)"
mkdir -p "${STAGING_DIR}"

# Run compilation
COMPILE_SCRIPT="${SCRIPT_DIR}/scripts/compile_standalone.m"
if [[ ! -f "$COMPILE_SCRIPT" ]]; then
    echo "ERROR: Compilation script not found: $COMPILE_SCRIPT"
    exit 1
fi

echo "  Compiling... (this takes 5-15 minutes)"
echo ""

matlab -nodisplay -nosplash -nodesktop -batch \
    "addpath('${SCRIPT_DIR}/scripts'); compile_standalone('${BST_DIR}', '${STAGING_DIR}')"

COMPILE_EXIT=$?
if [[ $COMPILE_EXIT -ne 0 ]]; then
    echo "ERROR: Compilation failed (exit code: ${COMPILE_EXIT})"
    exit $COMPILE_EXIT
fi

# Verify compiled binaries exist
if [[ ! -f "${STAGING_DIR}/bst_single_subject_standalone" ]]; then
    echo "ERROR: Compiled binary not found after compilation"
    ls -la "${STAGING_DIR}/"
    exit 1
fi

echo ""
echo "  Compilation successful!"
echo "  Binaries:"
ls -lh "${STAGING_DIR}"/bst_*_standalone 2>/dev/null || true
echo ""

# ─── Phase 2: Build Apptainer container ─────────────────────────────────────
if [[ "${SKIP_BUILD:-false}" == "true" ]]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo " Phase 2: SKIPPED (MCR zip not available)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo " Compiled binaries are in: ${STAGING_DIR}"
    echo " To complete the build:"
    echo "   1. Download MCR zip to ${MCR_ZIP}"
    echo "   2. Re-run this script (it will skip compilation if binaries exist)"
    echo ""
    exit 0
fi

echo "═══════════════════════════════════════════════════════════════════"
echo " Phase 2: Building Apptainer container"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  This will take 10-30 minutes (MCR extraction is slow)..."
echo ""

# Use APPTAINER_TMPDIR on scratch for large temp files
export APPTAINER_TMPDIR="${SCRATCH:-/tmp}/apptainer_mcr_tmp_$$"
mkdir -p "${APPTAINER_TMPDIR}"

apptainer build --fakeroot --notest "${OUTPUT}" "${DEF_FILE}"
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
    echo "  2. Test with a single subject (no module load matlab needed!):"
    echo "     apptainer run --writable-tmpfs \\"
    echo "         --bind /project/rrg-baillet-ab/databank/datasets/omega-tutorial:/data:ro \\"
    echo "         --bind /scratch/\$USER/test_output:/output \\"
    echo "         --bind \$SLURM_TMPDIR:/scratch \\"
    echo "         ${OUTPUT} /data /output participant \\"
    echo "         --participant-label 0002 --module import"
    echo ""
    echo "  3. Submit full pipeline (no MATLAB dependency!):"
    echo "     sbatch --array=0-5 slurm/array_job_mcr.sh"
else
    echo ""
    echo "ERROR: Build failed (exit code: ${BUILD_EXIT})"
    exit $BUILD_EXIT
fi

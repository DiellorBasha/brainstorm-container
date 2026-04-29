#!/bin/bash
# =============================================================================
# SLURM Job — Download MCR + Compile + Build MCR Container
# =============================================================================
# All-in-one job: downloads MCR R2023b, compiles standalone binaries, then
# builds the Apptainer container. Run on a compute node for disk space + time.
#
# Usage:
#   sbatch slurm/build_mcr_container.sh
# =============================================================================

#SBATCH --job-name=bst-build-mcr
#SBATCH --account=rrg-baillet-ab
#SBATCH --time=3:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --output=/scratch/dbasha/brainstorm_pipeline/logs/bst-build-mcr-%j.out
#SBATCH --error=/scratch/dbasha/brainstorm_pipeline/logs/bst-build-mcr-%j.err

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
REPO_DIR="$HOME/workspace/software/brainstorm-container"
BST_DIR="$HOME/workspace/software/brainstorm3"
STAGING_DIR="${REPO_DIR}/staging/compiled"
MCR_URL="https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/2/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_Update_2_glnxa64.zip"
MCR_ZIP="${STAGING_DIR}/MATLAB_Runtime_R2023b_glnxa64.zip"
OUTPUT_SIF="${REPO_DIR}/brainstorm-pipeline-mcr.sif"

echo "═══════════════════════════════════════════════════════════════════"
echo " MCR Container Build Job"
echo " Job ID: ${SLURM_JOB_ID}"
echo " Node: $(hostname)"
echo " Started: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

mkdir -p "${STAGING_DIR}"
mkdir -p /scratch/dbasha/brainstorm_pipeline/logs

# ─── Phase 1a: Download MCR ─────────────────────────────────────────────────
echo ""
echo "Phase 1a: Downloading MCR R2023b (~4.5 GB)..."
if [[ -f "$MCR_ZIP" ]]; then
    echo "  MCR zip already exists: $(du -h "$MCR_ZIP" | cut -f1)"
    echo "  Skipping download."
else
    echo "  URL: ${MCR_URL}"
    wget -q --show-progress -O "$MCR_ZIP" "$MCR_URL"
    echo "  Downloaded: $(du -h "$MCR_ZIP" | cut -f1)"
fi

# ─── Phase 1b: Compile standalone binaries ───────────────────────────────────
echo ""
echo "Phase 1b: Compiling standalone binaries..."
module load matlab/2023b.2
module load apptainer/1.3.5

if [[ -f "${STAGING_DIR}/bst_single_subject_standalone" ]]; then
    echo "  Compiled binaries already exist. Skipping compilation."
    ls -lh "${STAGING_DIR}"/bst_*_standalone
else
    echo "  MATLAB: $(which matlab)"
    echo "  BstDir: ${BST_DIR}"
    echo "  This takes 5-15 minutes..."
    echo ""

    matlab -nodisplay -nosplash -nodesktop -batch \
        "addpath('${REPO_DIR}/scripts'); compile_standalone('${BST_DIR}', '${STAGING_DIR}')"

    COMPILE_EXIT=$?
    if [[ $COMPILE_EXIT -ne 0 ]]; then
        echo "ERROR: Compilation failed (exit code: ${COMPILE_EXIT})"
        exit $COMPILE_EXIT
    fi

    echo "  Compilation successful!"
    ls -lh "${STAGING_DIR}"/bst_*_standalone 2>/dev/null
fi

# ─── Phase 2: Build Apptainer container ──────────────────────────────────────
echo ""
echo "Phase 2: Building Apptainer container..."
echo "  Definition: ${REPO_DIR}/brainstorm-pipeline-mcr.def"
echo "  Output: ${OUTPUT_SIF}"
echo "  This takes 10-30 minutes..."
echo ""

export APPTAINER_TMPDIR="${SLURM_TMPDIR}/apptainer_tmp"
mkdir -p "${APPTAINER_TMPDIR}"

cd "${REPO_DIR}"
apptainer build --fakeroot --notest --force "${OUTPUT_SIF}" brainstorm-pipeline-mcr.def
BUILD_EXIT=$?

if [[ $BUILD_EXIT -eq 0 ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo " BUILD SUCCESSFUL!"
    echo " Container: ${OUTPUT_SIF}"
    echo " Size: $(du -h "${OUTPUT_SIF}" | cut -f1)"
    echo " Finished: $(date)"
    echo "═══════════════════════════════════════════════════════════════════"

    # Copy to shared containers location
    SHARED_DEST="/project/rrg-baillet-ab/dbasha/workspace/software/containers/brainstorm-pipeline-mcr.sif"
    echo ""
    echo "Copying to shared location: ${SHARED_DEST}"
    cp "${OUTPUT_SIF}" "${SHARED_DEST}"
    ls -lh "${SHARED_DEST}"
    echo ""
    echo "Ready to test:"
    echo "  sbatch --array=0-0 slurm/array_job_mcr.sh"
else
    echo ""
    echo "ERROR: Container build failed (exit code: ${BUILD_EXIT})"
    exit $BUILD_EXIT
fi

#!/bin/bash
# =============================================================================
# SLURM Job — Aggregate per-subject exports into group protocol
# =============================================================================
# Runs after all array tasks complete. Combines per-subject .zip files into
# a single group protocol using bst_aggregate_subjects.m.
#
# Submit as a dependency on the array job:
#   sbatch --dependency=afterok:${ARRAY_JOB_ID} slurm/aggregate_job.sh
# =============================================================================

#SBATCH --job-name=bst-aggregate
#SBATCH --account=rrg-baillet-ab
#SBATCH --time=2:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=2
#SBATCH --output=/scratch/dbasha/brainstorm_pipeline/logs/bst-agg-%j.out
#SBATCH --error=/scratch/dbasha/brainstorm_pipeline/logs/bst-agg-%j.err

# ─── Configuration ───────────────────────────────────────────────────────────
PROTOCOL_NAME="OMEGA_Group"
OUTPUT_DIR="/scratch/dbasha/brainstorm_pipeline/derivatives"
OUTPUT_ZIP="/scratch/dbasha/brainstorm_pipeline/derivatives/${PROTOCOL_NAME}.zip"
CONTAINER="/project/rrg-baillet-ab/dbasha/workspace/software/containers/brainstorm-pipeline.sif"

# ─── Run ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════"
echo " Brainstorm Aggregate Job"
echo " Job ID: ${SLURM_JOB_ID}"
echo " Protocol: ${PROTOCOL_NAME}"
echo " Zip dir: ${OUTPUT_DIR}"
echo " Node: $(hostname)"
echo " Started: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# Verify zip files exist
ZIP_COUNT=$(ls "${OUTPUT_DIR}"/sub-*_brainstorm.zip 2>/dev/null | wc -l)
echo "Found ${ZIP_COUNT} subject .zip files in ${OUTPUT_DIR}"

if [[ $ZIP_COUNT -eq 0 ]]; then
    echo "ERROR: No subject zip files found. Did the array job complete?"
    exit 1
fi

ls -lh "${OUTPUT_DIR}"/sub-*_brainstorm.zip

# Load MATLAB
module load matlab/2023b.2

echo ""
echo "Running aggregate..."
echo ""

MATLAB_BIN=$(which matlab)
apptainer run \
    --cleanenv \
    --env "SLURM_TMPDIR=${SLURM_TMPDIR}" \
    --env "MATLAB_BIN=${MATLAB_BIN}" \
    --env "MLM_LICENSE_FILE=${MLM_LICENSE_FILE:-}" \
    --bind "${OUTPUT_DIR}:/output" \
    --bind "${SLURM_TMPDIR}:/scratch" \
    --bind "/cvmfs:/cvmfs:ro" \
    "${CONTAINER}" \
    aggregate \
    --zip-dir /output \
    --protocol-name "${PROTOCOL_NAME}" \
    --output-zip "/output/${PROTOCOL_NAME}.zip" \
    --bst-db-dir "/scratch/brainstorm_db"

EXIT_CODE=$?

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo " Finished: $(date)"
echo " Exit code: ${EXIT_CODE}"
if [[ $EXIT_CODE -eq 0 ]]; then
    echo " Group protocol: ${OUTPUT_ZIP}"
    ls -lh "${OUTPUT_ZIP}" 2>/dev/null || true
fi
echo "═══════════════════════════════════════════════════════════════════"

exit ${EXIT_CODE}

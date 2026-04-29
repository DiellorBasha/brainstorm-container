#!/bin/bash
# =============================================================================
# SLURM Job — Aggregate per-subject exports (MCR Version B)
# =============================================================================
# Same as aggregate_job.sh but uses the self-contained MCR container.
# No 'module load matlab' required.
#
# Submit as a dependency on the array job:
#   sbatch --dependency=afterok:${ARRAY_JOB_ID} slurm/aggregate_job_mcr.sh
# =============================================================================

#SBATCH --job-name=bst-mcr-agg
#SBATCH --account=rrg-baillet-ab
#SBATCH --time=2:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=2
#SBATCH --output=/scratch/dbasha/brainstorm_pipeline/logs/bst-mcr-agg-%j.out
#SBATCH --error=/scratch/dbasha/brainstorm_pipeline/logs/bst-mcr-agg-%j.err

# ─── Configuration ───────────────────────────────────────────────────────────
PROTOCOL_NAME="OMEGA_Group"
OUTPUT_DIR="/scratch/dbasha/brainstorm_pipeline/derivatives"
OUTPUT_ZIP="/scratch/dbasha/brainstorm_pipeline/derivatives/${PROTOCOL_NAME}.zip"
CONTAINER="/project/rrg-baillet-ab/dbasha/workspace/software/containers/brainstorm-pipeline-mcr.sif"

module load apptainer/1.3.5

# ─── Run ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════"
echo " Brainstorm Aggregate Job (MCR Version)"
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

echo ""
echo "Running aggregate..."
echo ""

apptainer run \
    --writable-tmpfs \
    --env "SLURM_TMPDIR=${SLURM_TMPDIR}" \
    --bind "${OUTPUT_DIR}:/output" \
    --bind "${SLURM_TMPDIR}:/scratch" \
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

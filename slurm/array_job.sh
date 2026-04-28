#!/bin/bash
# =============================================================================
# SLURM Array Job — Per-subject Brainstorm pipeline via container
# =============================================================================
# Processes each subject in parallel as a separate SLURM array task.
# Each task runs the full pipeline (import → preprocess → source → timefreq)
# for one subject, then exports a .zip to the shared output directory.
#
# Usage:
#   sbatch --array=0-4 slurm/array_job.sh
#
# The aggregate job (aggregate_job.sh) should be submitted as a dependency:
#   ARRAY_JOB_ID=$(sbatch --parsable --array=0-4 slurm/array_job.sh)
#   sbatch --dependency=afterok:${ARRAY_JOB_ID} slurm/aggregate_job.sh
#
# Or use the submit_pipeline.sh wrapper for convenience.
# =============================================================================

#SBATCH --job-name=bst-pipeline
#SBATCH --account=rrg-baillet-ab
#SBATCH --time=4:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1
#SBATCH --output=/scratch/dbasha/brainstorm_pipeline/logs/bst-%A_%a.out
#SBATCH --error=/scratch/dbasha/brainstorm_pipeline/logs/bst-%A_%a.err

# ─── Configuration ───────────────────────────────────────────────────────────
# Edit these for your dataset
SUBJECTS=(0002 0003 0004 0005 0006 0007)
MODULE="timefreq"
NVERTICES=15000

# Paths
BIDS_DIR="/project/rrg-baillet-ab/databank/datasets/omega-tutorial"
OUTPUT_DIR="/scratch/dbasha/brainstorm_pipeline/derivatives"
CONTAINER="/project/rrg-baillet-ab/dbasha/workspace/software/containers/brainstorm-pipeline.sif"

# ─── Resolve subject from array task ID ──────────────────────────────────────
if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "ERROR: This script must be submitted as a SLURM array job."
    echo "Usage: sbatch --array=0-$((${#SUBJECTS[@]}-1)) $0"
    exit 1
fi

SUBJECT="${SUBJECTS[$SLURM_ARRAY_TASK_ID]}"
echo "═══════════════════════════════════════════════════════════════════"
echo " SLURM Array Task: ${SLURM_ARRAY_TASK_ID}"
echo " Job ID: ${SLURM_JOB_ID}"
echo " Subject: sub-${SUBJECT}"
echo " Module: ${MODULE}"
echo " Node: $(hostname)"
echo " Started: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# ─── Environment ─────────────────────────────────────────────────────────────
module load matlab/2023b.2

# Create output directory
mkdir -p "${OUTPUT_DIR}"
mkdir -p "$(dirname ${SLURM_OUTPUT:-/dev/null})" 2>/dev/null || true

# ─── Run container ───────────────────────────────────────────────────────────
echo ""
echo "Running container: ${CONTAINER}"
echo "SLURM_TMPDIR: ${SLURM_TMPDIR}"
echo ""

apptainer run \
    --cleanenv \
    --env "SLURM_TMPDIR=${SLURM_TMPDIR}" \
    --bind "${BIDS_DIR}:/data:ro" \
    --bind "${OUTPUT_DIR}:/output" \
    --bind "${SLURM_TMPDIR}:/scratch" \
    "${CONTAINER}" \
    /data /output participant \
    --participant-label "${SUBJECT}" \
    --module "${MODULE}" \
    --nvertices "${NVERTICES}" \
    --bst-db-dir "/scratch/brainstorm_db"

EXIT_CODE=$?

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo " Finished: $(date)"
echo " Exit code: ${EXIT_CODE}"
if [[ $EXIT_CODE -eq 0 ]]; then
    echo " Output: ${OUTPUT_DIR}/sub-${SUBJECT}_brainstorm.zip"
    ls -lh "${OUTPUT_DIR}/sub-${SUBJECT}_brainstorm.zip" 2>/dev/null || true
fi
echo "═══════════════════════════════════════════════════════════════════"

exit ${EXIT_CODE}

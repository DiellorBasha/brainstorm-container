#!/bin/bash
# =============================================================================
# SLURM Array Job — Per-subject Brainstorm pipeline (MCR Version B)
# =============================================================================
# Same as array_job.sh but uses the self-contained MCR container.
# No 'module load matlab' required. No /cvmfs binding needed.
#
# Usage:
#   sbatch --array=0-5 slurm/array_job_mcr.sh
#
# The aggregate job (aggregate_job_mcr.sh) should be submitted as a dependency:
#   ARRAY_JOB_ID=$(sbatch --parsable --array=0-5 slurm/array_job_mcr.sh)
#   sbatch --dependency=afterok:${ARRAY_JOB_ID} slurm/aggregate_job_mcr.sh
# =============================================================================

#SBATCH --job-name=bst-mcr
#SBATCH --account=rrg-baillet-ab
#SBATCH --time=4:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1
#SBATCH --output=/scratch/dbasha/brainstorm_pipeline/logs/bst-mcr-%A_%a.out
#SBATCH --error=/scratch/dbasha/brainstorm_pipeline/logs/bst-mcr-%A_%a.err

# ─── Configuration ───────────────────────────────────────────────────────────
SUBJECTS=(0002 0003 0004 0005 0006 0007)
MODULE="timefreq"
NVERTICES=15000

# Paths
BIDS_DIR="/project/rrg-baillet-ab/databank/datasets/omega-tutorial"
OUTPUT_DIR="/scratch/dbasha/brainstorm_pipeline/derivatives"
CONTAINER="/project/rrg-baillet-ab/dbasha/workspace/software/containers/brainstorm-pipeline-mcr.sif"

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
echo " Container: MCR Version (self-contained)"
echo " Node: $(hostname)"
echo " Started: $(date)"
echo "═══════════════════════════════════════════════════════════════════"

# ─── Environment ─────────────────────────────────────────────────────────────
# No 'module load matlab' needed! MCR is bundled in the container.
module load apptainer/1.3.5
mkdir -p "${OUTPUT_DIR}"

# ─── Run container ───────────────────────────────────────────────────────────
echo ""
echo "Running MCR container: ${CONTAINER}"
echo "SLURM_TMPDIR: ${SLURM_TMPDIR}"
echo ""

apptainer run \
    --writable-tmpfs \
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

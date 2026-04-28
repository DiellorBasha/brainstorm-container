#!/bin/bash
# =============================================================================
# Submit the full Brainstorm pipeline: array job → aggregate
# =============================================================================
# Convenience wrapper that submits both jobs with proper dependencies.
#
# Usage:
#   ./slurm/submit_pipeline.sh                    # All subjects (0-5)
#   ./slurm/submit_pipeline.sh 0-1                # First 2 subjects only
#   ./slurm/submit_pipeline.sh 0-1 --no-aggregate # Skip aggregation
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARRAY_RANGE="${1:-0-5}"
NO_AGGREGATE="${2:-}"

# Create log directory
mkdir -p /scratch/dbasha/brainstorm_pipeline/logs

echo "Submitting Brainstorm pipeline..."
echo "  Array range: ${ARRAY_RANGE}"

# Submit array job
ARRAY_JOB_ID=$(sbatch --parsable --array="${ARRAY_RANGE}" "${SCRIPT_DIR}/array_job.sh")
echo "  Array job submitted: ${ARRAY_JOB_ID}"

# Submit aggregate as dependency (unless --no-aggregate)
if [[ "$NO_AGGREGATE" != "--no-aggregate" ]]; then
    AGG_JOB_ID=$(sbatch --parsable --dependency="afterok:${ARRAY_JOB_ID}" "${SCRIPT_DIR}/aggregate_job.sh")
    echo "  Aggregate job submitted: ${AGG_JOB_ID} (depends on ${ARRAY_JOB_ID})"
fi

echo ""
echo "Monitor with:"
echo "  squeue -u \$USER"
echo "  sacct -j ${ARRAY_JOB_ID} --format=JobID,JobName,State,Elapsed,MaxRSS"

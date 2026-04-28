#!/bin/bash
#SBATCH --job-name=bst-test-single
#SBATCH --time=4:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=1
#SBATCH --account=rrg-baillet-ab
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Test script for bst_single_subject.m on fir with omega-tutorial.
#
# This tests the core single-subject Brainstorm pipeline OUTSIDE
# a container, using MATLAB directly on the cluster. Once this works
# reliably, the same logic goes into the Docker container.
#
# Usage:
#   # Copy this script + bst_single_subject.m to fir, then:
#   sbatch test_single_subject_fir.sh [MODULE] [SUBJECT]
#
#   MODULE  = import | preprocess | source | timefreq (default: import)
#   SUBJECT = subject label without sub- prefix (default: 0002)

set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────────────
MODULE=${1:-import}
SUBLABEL=${2:-0002}
SUB="sub-${SUBLABEL}"

echo "=== BST Single Subject Test ==="
echo "Module:  $MODULE"
echo "Subject: $SUB"
echo "Node:    $(hostname)"
echo "Start:   $(date -Iseconds)"
echo ""

# ── Paths ──────────────────────────────────────────────────────────────────
BST_DIR=~/workspace/software/brainstorm3
SCRIPT_DIR=~/workspace/research/code/brainstorm-container/scripts
BIDS_SRC=/project/rrg-baillet-ab/databank/datasets/omega-tutorial

# Working directory on node-local storage
WORKDIR=$SLURM_TMPDIR/$SUB
mkdir -p $WORKDIR/output $WORKDIR/input

# ── Load MATLAB ────────────────────────────────────────────────────────────
module load matlab/2023b.2 2>/dev/null || {
    echo "ERROR: Failed to load matlab/2023b.2"
    exit 1
}
echo "MATLAB: $(which matlab)"

# ── Prepare BIDS data (single subject) ─────────────────────────────────────
echo ""
echo "--- Preparing BIDS data for $SUB ---"

# For testing, we'll use datalad to get the subject data.
# On a real run, the SLURM array wrapper handles this.
module load git-annex/10.20231129 2>/dev/null || true

# Clone the dataset
cd $WORKDIR
if command -v datalad &>/dev/null; then
    # If datalad is available, clone from RIA
    RIA_URL="ria+file:///project/rrg-baillet-ab/databank/ria/omega-tutorial#~omega-tutorial"
    echo "Cloning from RIA: $RIA_URL"
    datalad clone "$RIA_URL" input 2>&1 || {
        echo "RIA clone failed, falling back to direct copy"
        cp -r $BIDS_SRC/* input/
    }
    cd input

    # Get subject data + emptyroom + FreeSurfer derivatives
    datalad get $SUB/ dataset_description.json participants.tsv 2>/dev/null || true
    datalad get $SUB/
    datalad get sub-emptyroom/ 2>/dev/null || true
    datalad get derivatives/freesurfer/$SUB/ 2>/dev/null || true
else
    # No datalad — direct copy (slower but always works)
    echo "datalad not available, copying directly"
    cp -r $BIDS_SRC/* input/
fi

BIDS_DIR=$WORKDIR/input

# Unlock annex symlinks (MATLAB can't follow them)
echo "--- Unlocking annex files ---"
cd $BIDS_DIR
if [ -d ".git" ]; then
    (cd "$SUB" && git annex unlock . 2>/dev/null) || true
    [ -d "sub-emptyroom" ] && (cd "sub-emptyroom" && git annex unlock . 2>/dev/null) || true
    [ -d "derivatives/freesurfer/$SUB" ] && (cd "derivatives/freesurfer/$SUB" && git annex unlock . 2>/dev/null) || true
fi

# Strip DataLad artifacts for clean BIDS directory
echo "--- Stripping git artifacts ---"
chmod -R u+w .git 2>/dev/null; rm -rf .git .datalad .gitmodules .gitattributes 2>/dev/null || true
[ -d "$SUB/.git" ] && (chmod -R u+w "$SUB/.git" 2>/dev/null; rm -rf "$SUB/.git" "$SUB/.datalad" 2>/dev/null) || true
[ -d "sub-emptyroom/.git" ] && (chmod -R u+w "sub-emptyroom/.git" 2>/dev/null; rm -rf "sub-emptyroom/.git" "sub-emptyroom/.datalad" 2>/dev/null) || true
[ -d "derivatives" ] && (find derivatives -name ".git" -exec chmod -R u+w {} + 2>/dev/null; find derivatives \( -name ".git" -o -name ".datalad" \) -exec rm -rf {} + 2>/dev/null) || true

echo "Data preparation complete: $(date -Iseconds)"
echo ""

# ── Run MATLAB ─────────────────────────────────────────────────────────────
echo "--- Running bst_single_subject ---"
OUTPUT_DIR=$WORKDIR/output

matlab -nodisplay -nosplash -nodesktop \
    -r "try; \
            addpath('$SCRIPT_DIR'); \
            bst_single_subject('$BIDS_DIR', '$OUTPUT_DIR', '$SUBLABEL', '$MODULE', \
                'BstDir', '$BST_DIR', \
                'BstDbDir', fullfile(getenv('SLURM_TMPDIR'), 'brainstorm_db')); \
        catch e; \
            fprintf('ERROR: %s\n', e.message); \
            for k=1:length(e.stack); fprintf('  %s (line %d)\n', e.stack(k).name, e.stack(k).line); end; \
            exit(1); \
        end; \
        exit(0);" \
    2>&1

RC=$?
echo ""
echo "MATLAB exit code: $RC"

if [ $RC -ne 0 ]; then
    echo "FAILED: bst_single_subject returned error"
    exit $RC
fi

# ── Check output ───────────────────────────────────────────────────────────
echo ""
echo "--- Output files ---"
ls -lh $OUTPUT_DIR/
echo ""

# Copy results to a persistent location for inspection
RESULTS_DIR=~/workspace/research/results/bst-test-single/$SUB/$MODULE
mkdir -p $RESULTS_DIR
cp -v $OUTPUT_DIR/* $RESULTS_DIR/ 2>/dev/null || true

echo ""
echo "Results copied to: $RESULTS_DIR"
echo "End: $(date -Iseconds)"

#!/bin/bash
# =============================================================================
# Apply bugfixes to Brainstorm source tree
# =============================================================================
# Called during container build (%post) or manually when setting up Brainstorm.
#
# Bug: process_import_bids.m empty-room noise covariance handling
# - Variable name typo: iRaw → iRawEmpty (line ~1233)
# - Missing guard: sFilesEmpty may be empty if noisecov computation fails
#
# This script uses sed for reliable application regardless of exact line numbers.
# =============================================================================

set -e

BST_DIR="${1:-/opt/brainstorm3}"
BIDS_FILE="${BST_DIR}/toolbox/process/functions/process_import_bids.m"

if [[ ! -f "$BIDS_FILE" ]]; then
    echo "ERROR: process_import_bids.m not found at: $BIDS_FILE"
    exit 1
fi

echo "Applying bugfixes to: $BIDS_FILE"

# ─── Fix 1: Variable name typo ──────────────────────────────────────────────
# The upstream code uses 'iRaw' but the variable was renamed to 'iRawEmpty'
# a few lines above. This causes the wrong variable to be checked/used.
if grep -q "iRaw = find(file_compare(origEmptyFile, OrigFiles))" "$BIDS_FILE"; then
    sed -i 's/iRaw = find(file_compare(origEmptyFile, OrigFiles))/iRawEmpty = find(file_compare(origEmptyFile, OrigFiles))/' "$BIDS_FILE"
    sed -i 's/if isempty(iRaw)$/if isempty(iRawEmpty)/' "$BIDS_FILE"
    sed -i "s/sFilesEmpty = bst_process('CallProcess', 'process_noisecov', RawFiles{iRaw}/sFilesEmpty = bst_process('CallProcess', 'process_noisecov', RawFiles{iRawEmpty}/" "$BIDS_FILE"
    echo "  Fix 1 applied: iRaw → iRawEmpty"
else
    echo "  Fix 1: already applied or not needed (iRawEmpty already present)"
fi

# ─── Fix 2: Guard sFilesEmpty before loop ────────────────────────────────────
# If process_noisecov fails, sFilesEmpty is [] and the for loop crashes.
# Add an if-guard: if ~isempty(sFilesEmpty) && isstruct(sFilesEmpty)
if grep -q "Copy noisecov to all the matched folders" "$BIDS_FILE" && \
   ! grep -q "if ~isempty(sFilesEmpty) && isstruct(sFilesEmpty)" "$BIDS_FILE"; then
    # Insert the guard before the "for iDest" loop
    sed -i '/% Copy noisecov to all the matched folders/a\            if ~isempty(sFilesEmpty) \&\& isstruct(sFilesEmpty)' "$BIDS_FILE"
    # Add closing 'end' after the for-loop's end (the one that closes "for iDest")
    # Find the pattern: "end" followed by "end" (closing for iNoise) and insert between them
    # This is tricky with sed; use a Python one-liner if available
    if command -v python3 &>/dev/null; then
        python3 -c "
import re
with open('$BIDS_FILE', 'r') as f:
    content = f.read()
# Find the block: 'if ~isempty(sFilesEmpty)' ... 'end' (for iDest) and add closing 'end'
# Look for the pattern after our inserted if-guard
pattern = r'(% Copy noisecov to all the matched folders\n\s+if ~isempty\(sFilesEmpty\).*?\n(?:.*?\n)*?\s+end\n)(\s+end\n\s+end)'
match = re.search(pattern, content)
if match:
    # Insert 'end' after the for-loop's end
    insert_pos = match.start(2)
    content = content[:insert_pos] + '            end\n' + content[insert_pos:]
    with open('$BIDS_FILE', 'w') as f:
        f.write(content)
    print('  Fix 2 applied: added if-guard around noisecov copy loop')
else:
    print('  Fix 2: pattern not found — may need manual review')
"
    else
        echo "  WARNING: Python3 not available for Fix 2. Manual application needed."
    fi
else
    echo "  Fix 2: already applied (if-guard present)"
fi

echo "Bugfix application complete."

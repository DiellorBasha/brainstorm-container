# Brainstorm BIDS App — Architecture Plan

## Vision

Redesign `brainstorm-container` as a **BIDS App** that follows the same interface as FreeSurfer, fMRIPrep, and MRIQC containers from ReproNim. This allows `nsp-data-manager` to treat Brainstorm identically to any other container-based pipeline — eliminating 1700 lines of MATLAB script generation code and the entire `CustomExecutor` pathway.

The container uses **compiled Brainstorm** with MATLAB Runtime (no license required), making it portable to any HPC, cloud, or local environment.

---

## CLI Interface (BIDS App Standard)

```
brainstorm-pipeline <bids_dir> <output_dir> participant \
    --participant-label <label> \
    [--module <module_name>] \
    [--script <path_to_custom_script.m>] \
    [--session-label <ses>] \
    [--emptyroom-session <ses>] \
    [--skip-bids-validator] \
    [--freesurfer-dir <path>]
```

### Positional Arguments (BIDS App standard)

| Argument | Description |
|----------|-------------|
| `bids_dir` | Path to BIDS dataset root (read-only) |
| `output_dir` | Path for pipeline outputs |
| `participant` | Analysis level (only `participant` supported initially) |

### Required Arguments

| Flag | Description |
|------|-------------|
| `--participant-label` | Subject label without `sub-` prefix (e.g., `0002`) |

### Processing Mode (one required)

| Flag | Description |
|------|-------------|
| `--module <name>` | Run a built-in module: `import`, `preprocess`, `source`, `timefreq` |
| `--script <path>` | Run a user-provided `.m` script (bind-mounted into container) |

### Optional Arguments

| Flag | Description | Default |
|------|-------------|---------|
| `--session-label` | Session to process | all sessions |
| `--emptyroom-session` | Empty-room session for noise covariance | auto-detected by date |
| `--freesurfer-dir` | Path to FreeSurfer derivatives (for cortical surfaces) | `<bids_dir>/derivatives/freesurfer` |
| `--nvertices` | Cortex downsampling vertex count | `15000` |
| `--skip-bids-validator` | Skip BIDS validation | false |
| `--export-format` | Output format: `zip`, `flat`, `both` | `zip` |
| `--chain` | For modules: include all prerequisite stages | true |
| `--no-chain` | Run only the specified module (requires prior stage output) | — |
| `--input-derivatives` | Path to prior stage output (for `--no-chain` mode) | — |

---

## Execution Modes

### Mode 1: Built-in Module

```bash
apptainer run -B /data:/data:ro -B /out:/out \
    brainstorm-pipeline--2023a.sif \
    /data /out participant \
    --participant-label 0002 \
    --module source
```

The container runs the full dependency chain (import → preprocess → source) in a single invocation. Each stage builds on the previous one within an isolated throwaway protocol.

### Mode 2: Custom Script

```bash
apptainer run -B /data:/data:ro -B /out:/out -B ./scripts:/scripts:ro \
    brainstorm-pipeline--2023a.sif \
    /data /out participant \
    --participant-label 0002 \
    --script /scripts/my_connectivity.m
```

The container handles all boilerplate (BIDS import, protocol setup, Brainstorm server start), then sources the user's script with pre-initialized variables. The user script contains only their custom `bst_process` calls.

### Mode 3: Modular (no-chain)

```bash
apptainer run -B /data:/data:ro -B /out:/out -B /prev:/input-deriv:ro \
    brainstorm-pipeline--2023a.sif \
    /data /out participant \
    --participant-label 0002 \
    --module preprocess \
    --no-chain \
    --input-derivatives /input-deriv
```

For incremental processing: load a subject from a previous stage's exported `.zip` and run only the requested module. Useful when import takes time and you want to iterate on preprocessing parameters.

---

## Container Internal Architecture

```
/opt/brainstorm3/              # Compiled Brainstorm binaries
/opt/mcr/R2023a/               # MATLAB Runtime
/opt/bst-pipeline/             # Pipeline entrypoint + module definitions
    entrypoint.py              # Python CLI (argparse + orchestration)
    modules/
        __init__.py
        import_module.py       # MATLAB code for bst-import
        preprocess_module.py   # MATLAB code for bst-preprocess
        source_module.py       # MATLAB code for bst-source
        timefreq_module.py     # MATLAB code for bst-timefreq
    templates/
        header.m.jinja2        # Brainstorm server start + protocol setup
        footer.m.jinja2        # Export + cleanup
        custom_wrapper.m.jinja2  # Wraps user scripts
    utils/
        emptyroom.py           # Date-matching helper
        bids_prep.py           # Trim participants.tsv, verify structure
        export.py              # Handle export formats (zip, flat)
```

### Entrypoint Flow

```
entrypoint.py
    │
    ├─ 1. Parse CLI arguments (BIDS App interface)
    ├─ 2. Validate BIDS directory structure
    ├─ 3. Detect/resolve emptyroom session (date matching)
    ├─ 4. Verify FreeSurfer derivatives availability
    ├─ 5. Generate self-contained .m script:
    │       header (server start, protocol create, config bypass)
    │       + BIDS import section
    │       + module sections (with dependency chain if --chain)
    │       OR custom script wrapper
    │       + footer (export_protocol, cleanup)
    ├─ 6. Execute: xvfb-run brainstorm3.command $MCR_ROOT -script generated.m
    ├─ 7. Post-process: organize outputs, write provenance JSON
    └─ 8. Exit with appropriate code
```

### Pre-initialized Variables for Custom Scripts

When using `--script`, the user's `.m` file runs with these variables already set:

```matlab
% Available to custom scripts:
SubjectName   % e.g., 'sub-0002'
SubLabel      % e.g., '0002'  
BidsDir       % Path to BIDS root inside container
OutputDir     % Path to output directory
ProtocolName  % e.g., 'nsp_sub_0002'
sFilesRaw     % Data file references from BIDS import (if --chain or --module import ran)
sFilesBand    % Bandpass-filtered files (if preprocess ran)
sFilesRest    % Rest recordings (if preprocess ran)
sFilesSrc     % Source results (if source ran)
```

So a custom connectivity script might be:

```matlab
% my_connectivity.m — runs after import+preprocess+source
% sFilesSrc is already available from the built-in chain

% Compute coherence between scouts
sConn = bst_process('CallProcess', 'process_cohere1', sFilesSrc, [], ...
    'timewindow', [0, 100], ...
    'scouts', {'Desikan-Killiany', {'bankssts L', 'superiortemporal L'}}, ...
    'scoutfunc', 1, ...  % Mean
    'cohmeasure', 'mscohere');

fprintf('Connectivity analysis complete\n');
```

---

## Module Registry

Each module is defined as a Python class that returns MATLAB code:

```python
# modules/source_module.py
class SourceModule:
    name = "source"
    dependencies = ["import", "preprocess"]
    
    # SLURM resource hints (can be overridden by nsp pipeline YAML)
    default_resources = {"time": "3:00:00", "mem": "16G", "cpus": 1}
    
    def generate_matlab(self, context: dict) -> str:
        """Return the MATLAB bst_process calls for this module."""
        return '''
        %% Module: SOURCE — Noise covariance, head model, dSPM
        fprintf('\\n=== SOURCE: %s ===\\n', SubjectName);
        
        % Select noise recordings for noise covariance
        sFilesNoise = bst_process('CallProcess', 'process_select_tag', sFilesBand, [], ...
            'tag', 'task-noise', 'search', 1, 'select', 1);
        
        % Compute noise covariance
        bst_process('CallProcess', 'process_noisecov', sFilesNoise, [], ...
            'sensortypes', 'MEG', 'target', 1, ...
            'copycond', 1, 'copysubj', 1, 'copymatch', 1, 'replacefile', 1);
        
        % Head model — overlapping spheres
        bst_process('CallProcess', 'process_headmodel', sFilesRest, [], ...
            'sourcespace', 1, 'meg', 3);
        
        % dSPM inverse (kernel only)
        sFilesSrc = bst_process('CallProcess', 'process_inverse_2018', sFilesRest, [], ...
            'output', 2, 'inverse', struct(...
                'Comment', 'dSPM: MEG', ...
                'InverseMethod', 'minnorm', ...
                'InverseMeasure', 'dspm2018', ...
                'SourceOrient', {{'fixed'}}, ...
                'ComputeKernel', 1, ...
                'DataTypes', {{'MEG'}}));
        '''
```

---

## Output Structure (BIDS Derivatives)

```
<output_dir>/
    sub-0002/
        sub-0002_brainstorm.zip          # Full protocol export (import_subject compatible)
        sub-0002_module-source_desc.json  # Provenance metadata
        anat/                             # (flat export, optional)
            ...
        meg/
            ...
    dataset_description.json             # BIDS derivatives metadata
    participants.tsv                     # Processed subjects
```

The provenance JSON records:
```json
{
    "Subject": "sub-0002",
    "Module": "source",
    "ChainExecuted": ["import", "preprocess", "source"],
    "Container": "brainstorm-pipeline--2023a.sif",
    "BrainstormVersion": "3.230901",
    "MatlabRuntime": "R2023a (9.14)",
    "EmptyroomSession": "ses-18901014",
    "FreesurferUsed": true,
    "Nvertices": 15000,
    "ProcessingDate": "2026-04-28T14:30:00Z",
    "WallTime": "2h 15m 30s"
}
```

---

## Docker → Apptainer Conversion

The container must work with Apptainer on Alliance HPC clusters. Key considerations:

### Build Strategy

```bash
# Build Docker image
docker build -t brainstorm-pipeline:2023a .

# Convert to Apptainer .sif (on a machine with Docker)
apptainer build brainstorm-pipeline--2023a.sif docker://brainstorm-pipeline:2023a
```

The `.sif` file goes into the ReproNim containers dataset on fir:
```
~/workspace/software/containers/repronim/images/brainstorm-pipeline--2023a.sif
```

### Apptainer-Specific Adaptations

1. **Filesystem**: Apptainer mounts are read-only by default. The entrypoint uses `$TMPDIR` or `$SLURM_TMPDIR` for the throwaway protocol (not `/workspace`).
2. **User namespace**: Runs as the calling user (no `USER brainstorm` needed).
3. **Bind mounts**: nsp's SLURM template handles: `-B $WORKDIR/input:/data:ro -B $WORKDIR/output:/out -B /path/to/scripts:/scripts:ro`
4. **No xvfb in Apptainer**: Alliance nodes have no X server but `xvfb-run` works if xvfb is inside the container. The Dockerfile already includes it.
5. **MCR cache**: Must write to `$TMPDIR`, not hardcoded `/tmp/mcr_cache`.

### Environment Variable Handling

```bash
# The entrypoint detects Apptainer vs Docker:
if [ -n "$SLURM_TMPDIR" ]; then
    export MCR_CACHE_ROOT="$SLURM_TMPDIR/mcr_cache"
    export BST_DB_DIR="$SLURM_TMPDIR/brainstorm_db"
elif [ -n "$TMPDIR" ]; then
    export MCR_CACHE_ROOT="$TMPDIR/mcr_cache"
    export BST_DB_DIR="$TMPDIR/brainstorm_db"
else
    export MCR_CACHE_ROOT="/tmp/mcr_cache"
    export BST_DB_DIR="/tmp/brainstorm_db"
fi
```

---

## nsp Integration

### Pipeline YAML Configs

With this redesign, Brainstorm pipelines use the same `pathway: bidsapp` as FreeSurfer:

```yaml
# nsp/configs/bst-source.yaml
name: bst-source
description: "Brainstorm: import → preprocess → source (dSPM)"

pathway: bidsapp

container:
  image: brainstorm-pipeline--2023a.sif

bids_app:
  participant_label_style: hyphen
  args: ["--module", "source", "--skip-bids-validator"]

resources:
  time: "3:00:00"
  mem: "16G"
  cpus: 1

output:
  dirname: brainstorm-source
```

```yaml
# nsp/configs/bst-custom.yaml (template for user pipelines)
name: bst-custom
description: "Brainstorm: custom user script"

pathway: bidsapp

container:
  image: brainstorm-pipeline--2023a.sif

bids_app:
  participant_label_style: hyphen
  args: ["--script", "/scripts/custom_pipeline.m", "--skip-bids-validator"]

resources:
  time: "4:00:00"
  mem: "32G"
  cpus: 1

output:
  dirname: brainstorm-custom
```

### What Gets Removed from nsp-data-manager

Once the container is working:

| File | Lines | Action |
|------|-------|--------|
| `nsp/core/brainstorm.py` | 1707 | **Delete entirely** |
| `nsp/core/compute/custom_executor.py` | ~160 | **Delete entirely** |
| `nsp/templates/brainstorm_job.sh.jinja2` | ~170 | **Delete** |
| `nsp/configs/bst-*.yaml` | 4 files | **Rewrite** as bidsapp pathway |
| `nsp/core/compute/executor.py` (factory) | ~5 lines | Remove `custom` pathway |
| `tests/test_compute/test_executor.py` | ~20 lines | Remove CustomExecutor tests |

Net result: ~2000 lines removed from nsp-data-manager.

### SLURM Template

The existing `bidsapp_job.sh.jinja2` already works. The only addition needed is an optional `--bind-scripts` mechanism for custom `.m` files:

```jinja2
{% if custom_script_bind is defined and custom_script_bind %}
    -B {{ custom_script_bind }} \
{% endif %}
```

---

## Size Optimization Strategy

The MATLAB Runtime is ~3.5GB. Strategies to reduce:

1. **Toolbox pruning** (already explored in `Dockerfile.ultra-minimal`): Keep only `signal`, `parallel`, `matlab` core. Brainstorm primarily needs signal processing.

2. **Multi-stage build**: Build in full Ubuntu, copy only runtime artifacts to minimal base.

3. **Lazy anatomy downloads**: Don't bake default anatomy templates into the container. The entrypoint downloads them on first use (or they come from FreeSurfer derivatives).

4. **Shared layers**: If multiple containers use the same MCR version, the runtime layer is shared in the container registry.

Target: **~3-4GB** compressed `.sif` file (comparable to FreeSurfer containers).

---

## Testing Strategy

### Phase 1: Local Docker (development)

```bash
# Single-subject test with omega-tutorial
docker run --rm \
    -v /path/to/omega-tutorial:/data:ro \
    -v /tmp/bst-out:/out \
    brainstorm-pipeline:2023a \
    /data /out participant \
    --participant-label 0002 \
    --module import
```

### Phase 2: Apptainer on fir (integration)

```bash
# Convert and test
apptainer build brainstorm-pipeline--2023a.sif docker://brainstorm-pipeline:2023a

# Interactive test on compute node
salloc --time=1:00:00 --mem=16G --cpus-per-task=1 --account=rrg-baillet-ab
apptainer run -B $SCRATCH/omega-tutorial:/data:ro -B $SCRATCH/out:/out \
    brainstorm-pipeline--2023a.sif \
    /data /out participant --participant-label 0002 --module import
```

### Phase 3: nsp end-to-end (production)

```bash
# nsp treats it like any BIDS app
nsp compute omega-tutorial bst-source --dry-run
nsp compute omega-tutorial bst-source
```

### Validation Criteria

1. **Import module**: Output `.zip` can be loaded into standalone Brainstorm GUI
2. **Source module**: dSPM results match those from the legacy nsp pipeline (same dataset, same parameters)
3. **Custom script**: User `.m` file runs successfully with pre-initialized variables
4. **Performance**: Wall time within 10% of direct MATLAB execution (MCR startup overhead is acceptable)
5. **Reproducibility**: Same input → identical output across runs (bit-for-bit where MATLAB allows)

---

## Implementation Roadmap

### Sprint 1: Core Container (1-2 days)
- [ ] Rewrite `entrypoint.sh` → `entrypoint.py` with BIDS App CLI
- [ ] Implement import module (port from brainstorm.py `_section_import`)
- [ ] Implement preprocess module (port `_section_preprocess`)
- [ ] Add header/footer generation (protocol setup, export)
- [ ] Test locally with omega-tutorial sub-0002

### Sprint 2: Full Pipeline + Custom Scripts (1-2 days)
- [ ] Implement source and timefreq modules
- [ ] Implement custom script wrapper (pre-initialized variables)
- [ ] Add emptyroom date-matching
- [ ] Add provenance JSON output
- [ ] Test all 4 modules end-to-end

### Sprint 3: HPC Deployment (1 day)
- [ ] Build Apptainer `.sif` from Docker image
- [ ] Deploy to fir ReproNim containers
- [ ] Test with `salloc` interactive session
- [ ] Verify SLURM_TMPDIR handling for MCR cache + protocol DB

### Sprint 4: nsp Integration (1 day)
- [ ] Rewrite `bst-*.yaml` configs as `pathway: bidsapp`
- [ ] Add script bind-mount support to `bidsapp_job.sh.jinja2`
- [ ] Delete `brainstorm.py`, `custom_executor.py`, `brainstorm_job.sh.jinja2`
- [ ] Run `nsp compute omega-tutorial bst-source` end-to-end on fir
- [ ] Remove CustomExecutor from ExecutorFactory

### Sprint 5: Validation + Cleanup (1 day)
- [ ] Compare outputs against legacy pipeline results
- [ ] Update tests
- [ ] Push brainstorm-container to Docker Hub / GitHub Container Registry
- [ ] Document the custom script API
- [ ] Tag v1.0.0

---

## Open Questions

1. **MCR version**: The container uses R2023a. Brainstorm source on fir uses MATLAB 2023b. Any compatibility concerns with compiled vs source Brainstorm versions?

2. **Java/OpenJDK**: The compiled Brainstorm bundles its own JRE. The `sun.misc.BASE64Decoder` issue (Java 11+ breaks atlas loading) — is this fixed in the compiled version or do we need the same workaround?

3. **Aggregation step**: The per-subject parallel jobs produce `.zip` exports. The aggregation (import all subjects into one protocol) currently runs as a separate SLURM job. Should this be a `group` analysis level in the BIDS App, or remain in nsp as a finalize step?

4. **Container registry**: Docker Hub (public), GitHub Container Registry (tied to repo), or Alliance's own registry?

5. **Brainstorm updates**: When Brainstorm releases a new version, what's the rebuild/retag strategy? Pin to specific compiled releases?

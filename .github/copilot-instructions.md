# Brainstorm Container Project - AI Agent Instructions

## Project Overview
This is a Docker containerization project for running compiled Brainstorm (neuroscience data analysis software) in headless environments. The project enables batch processing of MEG/EEG/MRI/PET datasets without requiring MATLAB licenses, following Brainstorm's official scripting patterns and MATLAB Runtime installation guidelines.

## Architecture & Key Components

### Core Structure
- **Dockerfile**: Ubuntu 22.04 base with MATLAB Runtime R2023a (9.14) and Brainstorm compiled binaries
- **entrypoint.sh**: Bash wrapper handling `-script` mode and headless GUI execution via `xvfb-run`
- **scripts/**: User MATLAB scripts for Brainstorm pipeline automation (mounted at `/scripts`)
- **data/**: Brainstorm databases and datasets (mounted at `/data`)
- **docker-compose.yaml**: Convenience launcher with volume mappings

### Critical Dependencies
- **MATLAB Runtime R2023a (9.14)** (`MATLAB_Runtime_R2023a_glnxa64.zip`) - installed to `/opt/mcr/v914`
- **Brainstorm Compiled Binaries** (`brainstorm3_standalone_x86_64.zip`) - installed to `/opt/brainstorm`
- **X11/GUI Libraries**: Full set for headless operation (libx11-6, libxext6, xvfb, etc.)
- **Non-root User**: `brainstorm` user with proper permissions

## Development Workflows

### Build Process
```bash
# Requires downloaded archives in build context
docker build \
  --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip \
  --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip \
  -t brainstorm-compiled:2023a .
```

### Runtime Patterns
- **Script Mode**: `xvfb-run -a /opt/brainstorm/run_brainstorm.sh ${MCR_ROOT} -script /scripts/pipeline.m`
- **GUI Mode**: `xvfb-run -a /opt/brainstorm/run_brainstorm.sh ${MCR_ROOT}` (headless debugging)
- **Volume Strategy**: Always mount `/data` (Brainstorm databases) and `/scripts` (user .m files)
- **Environment Setup**: MCR_ROOT, LD_LIBRARY_PATH, MCR_CACHE_ROOT configured per MathWorks guidance

### Implementation Standards
- **Silent Installation**: MATLAB Runtime installed non-interactively following MathWorks patterns
- **Security**: Non-root execution with `brainstorm` user (UID/GID 1000)
- **Headless Operation**: All GUI-dependent operations wrapped with `xvfb-run -a`
- **Path Configuration**: Full LD_LIBRARY_PATH for R2023a runtime/bin/sys directories

## Project-Specific Conventions

### File Naming
- MATLAB Runtime installer: `MATLAB_Runtime_R2023a_glnxa64.zip`
- Brainstorm archive: `brainstorm3_standalone_x86_64.zip`
- Container tag format: `brainstorm-compiled:2023a`

### Volume Strategy
- `/data` → Brainstorm databases and project data
- `/scripts` → User MATLAB pipeline scripts
- `/tmp/mcr_cache` → MATLAB Runtime temporary cache

### Error Handling Patterns
- X11/GUI library dependencies for headless operation
- MATLAB Runtime version compatibility (must match R2023a/9.14)
- File permissions for cache directories and mounted volumes

## Integration Points
- **HPC Integration**: Compatible with SLURM, Nextflow, Snakemake workflows
- **Cloud Deployment**: Ready for containerized execution on cloud platforms
- **Brainstorm Scripting**: Follows Brainstorm's `-script` command-line interface

## Key Implementation Details
- **Brainstorm Launcher**: Uses `run_brainstorm.sh ${MCR_ROOT} <args>` pattern from compiled bundle
- **Script Generation**: Follows Brainstorm's "Generate .m script" tutorial for pipeline automation
- **Library Dependencies**: Complete X11/OpenGL stack for compiled MATLAB applications
- **Cache Management**: MCR_CACHE_ROOT at `/tmp/mcr_cache` with proper permissions
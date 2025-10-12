#!/bin/bash
# Entrypoint script for Brainstorm Compiled Container
# Supports both scripting mode (-script) and headless GUI execution
# References:
# - Brainstorm scripting tutorial: https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting
# - MathWorks compiled app execution: https://www.mathworks.com/help/compiler/package-and-distribute-matlab-functions.html
# - Headless execution: https://www.commandmasters.com/commands/xvfb-run-linux/

set -e

# Export required environment variables for MATLAB Runtime
export MCR_ROOT=${MCR_ROOT:-/opt/mcr/v914}
export MCR_CACHE_ROOT=${MCR_CACHE_ROOT:-/tmp/mcr_cache}
export LD_LIBRARY_PATH=${MCR_ROOT}/runtime/glnxa64:${MCR_ROOT}/bin/glnxa64:${MCR_ROOT}/sys/os/glnxa64:${MCR_ROOT}/sys/opengl/lib/glnxa64:${LD_LIBRARY_PATH}
export BRAINSTORM_ROOT=${BRAINSTORM_ROOT:-/opt/brainstorm}

# Ensure required directories exist and are writable
mkdir -p /data /tmp/mcr_cache /scripts
chmod 755 /data /tmp/mcr_cache /scripts 2>/dev/null || true

# Brainstorm executable path
BST_RUNNER="/opt/brainstorm3/bin/R2023a/brainstorm3.command"

# Check if Brainstorm runner exists
if [[ ! -f "${BST_RUNNER}" ]]; then
    echo "ERROR: Brainstorm runner not found at ${BST_RUNNER}"
    echo "Please ensure the Brainstorm compiled archive was properly installed."
    exit 1
fi

# Function to show usage
show_usage() {
    echo "Brainstorm Compiled Container"
    echo "Runs compiled Brainstorm with MATLAB Runtime R2023a (9.14) in headless mode"
    echo ""
    echo "Usage patterns:"
    echo "  Script mode (batch processing):"
    echo "    docker run -v \$PWD/data:/data -v \$PWD/scripts:/scripts brainstorm-compiled:2023a -script /scripts/pipeline.m"
    echo ""
    echo "  Headless GUI mode (debugging):"
    echo "    docker run -it -v \$PWD/data:/data brainstorm-compiled:2023a"
    echo ""
    echo "  With additional parameters:"
    echo "    docker run -v \$PWD/data:/data brainstorm-compiled:2023a -script /scripts/job.m local"
    echo ""
    echo "Volume requirements:"
    echo "  /data    - Mount your Brainstorm databases and project data"
    echo "  /scripts - Mount your .m script files generated from Brainstorm GUI"
    echo ""
    echo "Script generation: Follow Brainstorm's 'Generate .m script' tutorial"
    echo "Documentation: https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting"
}

# Handle help and no arguments
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Detect execution mode and prepare command
if [[ "$1" == "-script" ]]; then
    # Script mode: Run MATLAB script headlessly
    # Pattern: brainstorm3.command <MATLABROOT> <script.m> <parameters>
    echo "Running Brainstorm in script mode..."
    if [[ -z "$2" ]]; then
        echo "ERROR: -script requires a script file path"
        echo "Example: -script /scripts/my_pipeline.m"
        exit 1
    fi
    
    script_file="$2"
    if [[ ! -f "$script_file" ]]; then
        echo "ERROR: Script file not found: $script_file"
        echo "Ensure your script is mounted at /scripts and the path is correct"
        exit 1
    fi
    
    echo "Executing script: $script_file"
    # Correct Brainstorm pattern: brainstorm3.command <MATLABROOT> <script.m> <parameters>
    shift  # Remove -script
    exec xvfb-run -a "${BST_RUNNER}" "${MCR_ROOT}" "$@"
    
else
    # Direct mode: Start Brainstorm GUI or with custom arguments
    # Pattern: brainstorm3.command <MATLABROOT> [arguments]
    echo "Running Brainstorm with arguments: $*"
    if [[ $# -eq 0 ]]; then
        # No arguments = start GUI mode
        exec xvfb-run -a "${BST_RUNNER}" "${MCR_ROOT}"
    else
        # Pass arguments directly to Brainstorm
        exec xvfb-run -a "${BST_RUNNER}" "${MCR_ROOT}" "$@"
    fi
fi
# Dockerfile for Brainstorm Compiled Application with MATLAB Runtime R2023a (9.14)
# Based on Brainstorm installation docs: https://neuroimage.usc.edu/brainstorm/Installation
# Follows MATLAB Runtime installation guidance: https://www.mathworks.com/help/compiler/install-the-matlab-runtime.html
# Supports headless execution via xvfb-run: https://www.commandmasters.com/commands/xvfb-run-linux/

FROM ubuntu:22.04

# Build arguments for configurable installer files
ARG MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip
ARG BST_ARCHIVE=brainstorm3_standalone_x86_64.zip

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set UTF-8 locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install required OS packages for MATLAB Runtime and X11/GUI support
# Based on MathWorks system requirements for R2023a and headless GUI operation
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    ca-certificates \
    locales \
    unzip \
    xz-utils \
    fontconfig \
    libfreetype6 \
    libx11-6 \
    libxext6 \
    libxmu6 \
    libxpm4 \
    libxt6 \
    libxrender1 \
    libxi6 \
    libxtst6 \
    libxss1 \
    libglib2.0-0 \
    libasound2 \
    libnss3 \
    xvfb \
    mesa-utils \
    libxkbcommon0 \
    libxrandr2 \
    libxcursor1 \
    libxinerama1 \
    libxdamage1 \
    libxcomposite1 \
    libxfixes3 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libcairo2 \
    libpango-1.0-0 \
    libatk1.0-0 \
    libgconf-2-4 \
    libdrm2 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user for security
RUN groupadd -r brainstorm --gid=1000 && \
    useradd -r -g brainstorm --uid=1000 --home-dir=/home/brainstorm --shell=/bin/bash brainstorm && \
    mkdir -p /home/brainstorm && \
    chown -R brainstorm:brainstorm /home/brainstorm

# Set MATLAB Runtime environment variables
# Following MathWorks guidance for R2023a (9.14) path configuration
ENV MCR_ROOT=/opt/mcr/v914
ENV MCR_CACHE_ROOT=/tmp/mcr_cache
ENV LD_LIBRARY_PATH=${MCR_ROOT}/runtime/glnxa64:${MCR_ROOT}/bin/glnxa64:${MCR_ROOT}/sys/os/glnxa64:${MCR_ROOT}/sys/opengl/lib/glnxa64:${LD_LIBRARY_PATH}
ENV BRAINSTORM_ROOT=/opt/brainstorm

# Copy installer files from build context
COPY ${MCR_INSTALLER} /tmp/
COPY ${BST_ARCHIVE} /tmp/

# Install MATLAB Runtime R2023a (9.14) non-interactively
# Following MathWorks silent installation documentation
RUN cd /tmp && \
    unzip -q ${MCR_INSTALLER} && \
    ./install -mode silent -agreeToLicense yes -destinationFolder /opt/mcr && \
    rm -rf /tmp/install /tmp/${MCR_INSTALLER} /tmp/_temp_matlab_*

# Install Brainstorm compiled application
# Based on Brainstorm standalone installation guidance
RUN cd /tmp && \
    unzip -q ${BST_ARCHIVE} -d /opt/brainstorm && \
    chmod +x /opt/brainstorm/run_brainstorm.sh && \
    rm -rf /tmp/${BST_ARCHIVE}

# Create required directories and set permissions
# /data: Brainstorm databases and results
# /scripts: User MATLAB scripts for pipeline automation
# /workspace: Working directory
# /tmp/mcr_cache: MATLAB Runtime cache
RUN mkdir -p /data /scripts /workspace /tmp/mcr_cache && \
    chown -R brainstorm:brainstorm /data /scripts /workspace /tmp/mcr_cache

# Define volumes for data and scripts
VOLUME ["/data", "/scripts"]

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER brainstorm

# Health check - verify Brainstorm can show help
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/brainstorm/run_brainstorm.sh ${MCR_ROOT} -help > /dev/null 2>&1 || exit 1

# Set entrypoint and default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--help"]
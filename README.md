# brainstorm-container

# Brainstorm Compiled Docker Container

Run the **compiled version of [Brainstorm](https://neuroimage.usc.edu/brainstorm)** in a fully isolated and reproducible environment using **Docker**.
This container is designed for **headless (non-interactive)** execution of Brainstorm pipelines and scripts, powered by the **MATLAB Runtime R2023a (9.14)**.

It provides an easy way to execute Brainstorm processing pipelines on servers, clusters, or cloud environments **without requiring a MATLAB license**.

---

## 📘 Table of Contents

* [Overview](#overview)
* [Features](#features)
* [System Requirements](#system-requirements)
* [Repository Structure](#repository-structure)
* [Installation Guide](#installation-guide)
  * [1. Prerequisites](#1-prerequisites)
  * [2. Prepare Installation Files](#2-prepare-installation-files)
  * [3. Build the Docker Image](#3-build-the-docker-image)
* [Usage](#usage)
  * [Running Brainstorm Scripts](#running-brainstorm-scripts)
  * [Headless GUI Mode](#headless-gui-mode)
  * [Mounting Data Volumes](#mounting-data-volumes)
  * [Example Commands](#example-commands)
* [Environment Variables](#environment-variables)
* [Troubleshooting](#troubleshooting)
* [References](#references)
* [License](#license)

---

## 🧩 Overview

This Docker container allows you to execute **compiled Brainstorm applications** with the required **MATLAB Runtime R2023a (9.14)** pre-installed.

It is based on:

* The official **Brainstorm compiled binaries**, which can be downloaded from the [Brainstorm Download Page](https://neuroimage.usc.edu/brainstorm/Installation#Download_the_compiled_version).
* The official **MathWorks MATLAB Runtime** for **R2023a (9.14)**, available [here](https://www.mathworks.com/products/compiler/matlab-runtime.html).

The container can be used for:

* Automated batch processing of MEG/EEG/MRI/PET datasets
* Integration with HPC pipelines or workflow managers (e.g., Nextflow, Snakemake, SLURM)
* Development and testing of Brainstorm pipelines without needing MATLAB installed

---

## 🚀 Features

✅ Runs **compiled Brainstorm** binaries with full MATLAB Runtime support
✅ Includes **MATLAB Runtime R2023a (9.14)** configured for Linux (`glnxa64`)
✅ Supports **headless execution** via `xvfb-run` for GUI-linked operations
✅ Configurable **volumes** for data and script sharing
✅ Lightweight Ubuntu 22.04 base image with all required system dependencies
✅ Compatible with Brainstorm scripting workflows (`-script` mode)
✅ Ready for deployment on **servers**, **HPC clusters**, or **cloud** platforms

---

## 🖥️ System Requirements

| Requirement             | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| OS                      | Any system capable of running Docker (Linux, macOS, Windows WSL2) |
| Docker                  | Version 20.10 or higher                                           |
| Disk space              | ~5–6 GB (MATLAB Runtime + Brainstorm + base image)                |
| Memory                  | ≥ 2 GB recommended for small jobs                                 |
| Brainstorm compiled app | Downloaded `.zip` or `.tar.gz` version for Linux                  |
| MATLAB Runtime          | R2023a (9.14) for Linux (`glnxa64`)                               |

---

## 📁 Repository Structure

```
brainstorm-compiled-docker/
│
├── Dockerfile                 # Builds the container with MATLAB Runtime and Brainstorm
├── entrypoint.sh              # Wrapper for Brainstorm execution (script/headless modes)
├── README.md                  # This documentation file
├── docker-compose.yaml        # Optional convenience launcher
├── scripts/
│   └── bst_pipeline.m         # Example Brainstorm script (batch processing)
└── data/                      # Placeholder for Brainstorm database (mounted at runtime)
```

---

## ⚙️ Installation Guide

### 1️ Prerequisites

Before building, download the following files and place them in the repository root:

1. **Brainstorm Compiled Package**
   From the Brainstorm installation page:
   [https://neuroimage.usc.edu/brainstorm/Installation](https://neuroimage.usc.edu/brainstorm/Installation)
   Example file:

   ```
   brainstorm3_standalone_x86_64.zip
   ```

2. **MATLAB Runtime R2023a (9.14)**
   From MathWorks:
   [https://www.mathworks.com/products/compiler/matlab-runtime.html](https://www.mathworks.com/products/compiler/matlab-runtime.html)
   Example file:

   ```
   MATLAB_Runtime_R2023a_glnxa64.zip
   ```

---

### 2️ Prepare Installation Files

Ensure both downloaded archives are in your build context (same folder as the Dockerfile):

```
brainstorm-compiled-docker/
├── MATLAB_Runtime_R2023a_glnxa64.zip
├── brainstorm3_standalone_x86_64.zip
└── Dockerfile
```

---

### 3️ Build the Docker Image

Run the following command to build the container:

```bash
docker build \
  --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip \
  --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip \
  -t brainstorm-compiled:2023a .
```

This will:

* Install MATLAB Runtime to `/opt/mcr/v914`
* Install Brainstorm to `/opt/brainstorm`
* Configure all required environment variables

---

## 🧠 Usage

### Running Brainstorm Scripts

You can execute Brainstorm `.m` scripts in headless mode using the `-script` flag.
Example (assuming your scripts and database folders are in the current directory):

```bash
docker run --rm \
  -v $PWD/data:/data \
  -v $PWD/scripts:/scripts \
  brainstorm-compiled:2023a \
  -script /scripts/bst_pipeline.m
```

This runs the script `/scripts/bst_pipeline.m` using the compiled Brainstorm engine.
Refer to the [Brainstorm Scripting Tutorial](https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting) for generating `.m` scripts from GUI pipelines.

---

### Headless GUI Mode

If you need to run Brainstorm with its GUI (e.g., for debugging), use `xvfb-run`:

```bash
docker run --rm -it \
  -v $PWD/data:/data \
  brainstorm-compiled:2023a
```

This launches Brainstorm in a **virtual X display** without requiring a graphical desktop.

---

### Mounting Data Volumes

* `/data` → Mounted Brainstorm database and project data
* `/scripts` → User MATLAB `.m` scripts and pipelines

Both are defined as Docker volumes and can be mapped at runtime:

```bash
-v /path/to/local/data:/data
-v /path/to/local/scripts:/scripts
```

---

### Example Commands

**Run a pipeline script:**

```bash
docker run --rm \
  -v $(pwd)/data:/data \
  -v $(pwd)/scripts:/scripts \
  brainstorm-compiled:2023a \
  -script /scripts/my_analysis.m
```

**Specify a database and protocol:**

```bash
docker run --rm \
  -v $(pwd)/data:/data \
  -v $(pwd)/scripts:/scripts \
  brainstorm-compiled:2023a \
  -script /scripts/my_pipeline.m \
  --db /data --protocol TutorialIntroduction
```

**Display Brainstorm help:**

```bash
docker run --rm brainstorm-compiled:2023a --help
```

---

## ⚙️ Environment Variables

| Variable          | Description                      | Default           |
| ----------------- | -------------------------------- | ----------------- |
| `MCR_ROOT`        | MATLAB Runtime installation path | `/opt/mcr/v914`   |
| `MCR_CACHE_ROOT`  | Temporary runtime cache path     | `/tmp/mcr_cache`  |
| `LD_LIBRARY_PATH` | Library paths for MATLAB Runtime | Set automatically |
| `BRAINSTORM_ROOT` | Brainstorm installation path     | `/opt/brainstorm` |

---

## 🧩 Troubleshooting

**🛑 Error:** “libXrender.so.1: cannot open shared object file”
→ Ensure all required X libraries are installed in the container (these are preinstalled).

**🛑 Error:** “MCR not found or version mismatch”
→ Verify the compiled Brainstorm version matches MATLAB Runtime R2023a (9.14).

**🛑 Error:** “Permission denied writing to cache”
→ Ensure `/tmp/mcr_cache` and `/data` directories are writable (`chmod 777` as needed).

**🛑 Slow startup**
→ The MATLAB Runtime initializes on first run; subsequent runs are faster.

---

## 📚 References

* **Brainstorm Documentation**

  * [Brainstorm Installation Guide](https://neuroimage.usc.edu/brainstorm/Installation)
  * [Brainstorm Scripting Tutorial](https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting)
* **MATLAB Runtime**

  * [MATLAB Runtime R2023a (9.14) Download](https://www.mathworks.com/products/compiler/matlab-runtime.html)
  * [Noninteractive Installation Instructions (MathWorks)](https://www.mathworks.com/help/compiler/install-the-matlab-runtime.html)
* **Docker**

  * [Docker Documentation](https://docs.docker.com/engine/reference/run/)

---

## 🪪 License

This repository contains setup code licensed under the **MIT License**.
The **Brainstorm application** and **MATLAB Runtime** are distributed under their respective licenses:

* **Brainstorm:** Free for academic use (see [Brainstorm License Terms](https://neuroimage.usc.edu/brainstorm/License)).
* **MATLAB Runtime:** Free for redistribution per MathWorks terms.

---

## 🧬 Acknowledgements

Developed with ❤️ to make Brainstorm pipelines portable, reproducible, and easy to run on any system.
Based on work by the **Brainstorm team** (McGill University, USC, CNRS).

# Brainstorm Compiled Container

[![Docker Image Size](https://img.shields.io/docker/image-size/diellorbasha/brainstorm-compiled/2023a?label=Image%20Size)](https://hub.docker.com/r/diellorbasha/brainstorm-compiled)
[![Docker Pulls](https://img.shields.io/docker/pulls/diellorbasha/brainstorm-compiled?label=Docker%20Pulls)](https://hub.docker.com/r/diellorbasha/brainstorm-compiled)

**Production-ready Docker container for running [Brainstorm](https://neuroimage.usc.edu/brainstorm) neuroscience analysis pipelines in headless environments.**

This container packages the compiled version of Brainstorm with MATLAB Runtime R2023a (9.14), enabling **MEG/EEG/MRI/PET data processing** on servers, HPC clusters, and cloud platforms **without requiring a MATLAB license**.

## 🚀 Quick Start

```bash
# Pull the container
docker pull diellorbasha/brainstorm-compiled:2023a

# Test it works
docker run --rm diellorbasha/brainstorm-compiled:2023a --help

# Run with your Brainstorm scripts
docker run --rm \
  -v $PWD/data:/data \
  -v $PWD/scripts:/scripts \
  diellorbasha/brainstorm-compiled:2023a \
  -script /scripts/my_pipeline.m
```

## 📋 What's Included

- **Brainstorm Compiled** (Version: 30-Sep-2025) - Full neuroscience analysis toolkit
- **MATLAB Runtime R2023a (9.14)** - No MATLAB license required
- **Complete Plugin Suite**: brain2mesh, iso2mesh, fastica, mvgc, nirstorm, and more
- **Headless Operation** - GUI operations via xvfb-run for server environments
- **Ubuntu 22.04 Base** - Stable, secure foundation with all required X11/GUI libraries

## 🧠 Use Cases

- **Batch Processing**: Automated analysis of large MEG/EEG datasets
- **HPC Integration**: Seamless deployment on SLURM, PBS, SGE clusters  
- **Cloud Computing**: Ready for AWS, Azure, Google Cloud execution
- **CI/CD Pipelines**: Automated neuroscience workflows and testing
- **Reproducible Research**: Consistent analysis environment across platforms

## 📖 Usage Patterns

### Script Mode (Recommended)
Execute Brainstorm `.m` scripts generated from the GUI:

```bash
docker run --rm \
  -v /path/to/your/data:/data \
  -v /path/to/your/scripts:/scripts \
  diellorbasha/brainstorm-compiled:2023a \
  -script /scripts/my_analysis.m
```

### Direct Brainstorm Commands
Call Brainstorm functions directly:

```bash
# Basic execution with local database
docker run --rm \
  -v $PWD/scripts:/scripts \
  diellorbasha/brainstorm-compiled:2023a \
  /scripts/pipeline.m local

# Server mode for interactive debugging
docker run --rm -it \
  -v $PWD/data:/data \
  diellorbasha/brainstorm-compiled:2023a
```

### Docker Compose
For persistent development workflows:

```yaml
version: '3.8'
services:
  brainstorm:
    image: diellorbasha/brainstorm-compiled:2023a
    volumes:
      - ./data:/data
      - ./scripts:/scripts
    command: ["-script", "/scripts/analysis.m"]
```

## 📁 Volume Strategy

| Path | Purpose | Required |
|------|---------|----------|
| `/data` | Brainstorm databases, protocols, and results | Recommended |
| `/scripts` | Your MATLAB/Brainstorm `.m` script files | Required for script mode |

**Example directory structure:**
```
your-project/
├── data/                    # Mount to /data
│   ├── protocol1/
│   └── brainstorm_db/
└── scripts/                 # Mount to /scripts
    ├── preprocessing.m
    └── analysis_pipeline.m
```

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCR_ROOT` | `/opt/mcr/R2023a` | MATLAB Runtime installation path |
| `MCR_CACHE_ROOT` | `/tmp/mcr_cache` | Runtime cache directory |
| `BRAINSTORM_ROOT` | `/opt/brainstorm3` | Brainstorm installation path |

## 🧪 Examples

### Simple MATLAB Test
```bash
# Test basic MATLAB functionality
docker run --rm diellorbasha/brainstorm-compiled:2023a \
  -c "fprintf('MATLAB %s\\n', version); exit(0)"
```

### MEG/EEG Analysis Pipeline
```bash
# Process MEG data with custom protocol
docker run --rm \
  -v /research/meg_data:/data \
  -v /research/scripts:/scripts \
  diellorbasha/brainstorm-compiled:2023a \
  -script /scripts/meg_preprocessing.m
```

### Batch Processing Multiple Subjects
```bash
# Process multiple subjects in parallel
for subject in subj01 subj02 subj03; do
  docker run --rm -d \
    -v /study/data:/data \
    -v /study/scripts:/scripts \
    --name brainstorm-$subject \
    diellorbasha/brainstorm-compiled:2023a \
    -script /scripts/process_subject.m $subject &
done
```

## 🏗️ HPC Integration

### SLURM Job Script
```bash
#!/bin/bash
#SBATCH --job-name=brainstorm-analysis
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=02:00:00
#SBATCH --mem=8GB

# Load Singularity/Docker module
module load singularity

# Convert Docker image to Singularity (one-time setup)
singularity pull brainstorm.sif docker://diellorbasha/brainstorm-compiled:2023a

# Run analysis
singularity run \
  --bind /scratch/data:/data \
  --bind /home/user/scripts:/scripts \
  brainstorm.sif -script /scripts/hpc_analysis.m
```

### Nextflow Pipeline
```groovy
process brainstormAnalysis {
    container 'diellorbasha/brainstorm-compiled:2023a'
    
    input:
    path script
    path data
    
    output:
    path "results/*"
    
    script:
    """
    brainstorm-compiled -script ${script}
    """
}
```

## 📚 Script Development

### Creating Brainstorm Scripts
1. **Use Brainstorm GUI** to design your analysis pipeline
2. **Generate .m script** using Brainstorm's "Generate .m script" feature
3. **Follow the tutorial**: [Brainstorm Scripting Guide](https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting)
4. **Test locally** before containerizing

### Script Template
```matlab
function my_analysis()
% Brainstorm analysis pipeline
% Generated from Brainstorm GUI

% Initialize Brainstorm in server mode
if ~brainstorm('status')
    brainstorm nogui
end

% Your analysis steps here...
% (Generated from Brainstorm GUI)

% Clean exit
exit(0);
end
```

## ⚡ Performance Considerations

- **First run**: 3-5 minutes startup time (MATLAB Runtime initialization)
- **Subsequent runs**: ~30 seconds startup time
- **Memory**: Minimum 4GB RAM recommended, 8GB+ for large datasets
- **CPU**: Multi-core recommended for parallel processing
- **Storage**: Container size ~5.6GB, allow extra space for data processing

## 🔍 Troubleshooting

### Common Issues

**Container exits immediately**
```bash
# Check if script file exists and has correct path
docker run --rm -v $PWD/scripts:/scripts diellorbasha/brainstorm-compiled:2023a ls -la /scripts/
```

**"Database directory" prompts**
```bash
# Always use 'local' parameter for automatic database setup
docker run --rm diellorbasha/brainstorm-compiled:2023a /scripts/analysis.m local
```

**Memory errors**
```bash
# Increase Docker memory allocation or add memory limits
docker run --rm -m 8g diellorbasha/brainstorm-compiled:2023a -script /scripts/analysis.m
```

**Permission issues**
```bash
# Ensure data directories are writable
sudo chown -R 1000:1000 ./data ./scripts
```

## 🔗 References & Documentation

### Official Resources
- **Brainstorm Website**: https://neuroimage.usc.edu/brainstorm
- **Brainstorm Installation**: https://neuroimage.usc.edu/brainstorm/Installation
- **Scripting Tutorial**: https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting
- **Forum Support**: https://neuroimage.usc.edu/forums

### MATLAB Runtime
- **MathWorks Runtime**: https://www.mathworks.com/products/compiler/matlab-runtime.html
- **R2023a Documentation**: https://www.mathworks.com/help/compiler/install-the-matlab-runtime.html

### Container Resources
- **Source Code**: https://github.com/DiellorBasha/brainstorm-container
- **Docker Hub**: https://hub.docker.com/r/diellorbasha/brainstorm-container
- **Issues & Support**: https://github.com/DiellorBasha/brainstorm-container/issues

## 🏷️ Tags & Versions

| Tag | MATLAB Runtime | Brainstorm Version | Size | Notes |
|-----|----------------|-------------------|------|--------|
| `2023a`, `latest` | R2023a (9.14) | 30-Sep-2025 | ~5.6GB | Production ready |

## 📄 Licensing

- **Container Code**: MIT License
- **Brainstorm**: Free for academic use ([License](https://neuroimage.usc.edu/brainstorm/License))
- **MATLAB Runtime**: Free redistribution per MathWorks terms

## 🤝 Contributing

Found an issue or want to contribute improvements?
- **Issues**: https://github.com/DiellorBasha/brainstorm-container/issues
- **Pull Requests**: https://github.com/DiellorBasha/brainstorm-container/pulls
- **Discussions**: https://github.com/DiellorBasha/brainstorm-container/discussions

## 🎯 Citation

If you use this container in your research, please cite:

```bibtex
@software{brainstorm_container_2025,
  title={Brainstorm Compiled Docker Container},
  author={Diellor Basha},
  year={2025},
  url={https://hub.docker.com/r/diellorbasha/brainstorm-compiled},
  note={Container for headless Brainstorm neuroscience analysis}
}
```

And don't forget to cite Brainstorm itself:
```bibtex
@article{brainstorm2011,
  title={Brainstorm: a user-friendly application for MEG/EEG analysis},
  author={Tadel, Fran{\c{c}}ois and Baillet, Sylvain and Mosher, John C and Pantazis, Dimitrios and Leahy, Richard M},
  journal={Computational intelligence and neuroscience},
  volume={2011},
  year={2011},
  publisher={Hindawi}
}
```

---

**Built with ❤️ for the neuroscience community**

*Making Brainstorm analysis portable, reproducible, and accessible in any compute environment.*
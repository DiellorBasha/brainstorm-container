# Brainstorm Data Directory

This directory is designed to be mounted as `/data` in the Brainstorm container.

## Usage

Mount your Brainstorm database and project files here:

```bash
docker run --rm \
  -v $PWD/data:/data \
  -v $PWD/scripts:/scripts \
  brainstorm-compiled:2023a \
  -script /scripts/bst_pipeline.m
```

## Contents

Place your Brainstorm database folders and data files in this directory:

- **Protocol folders**: Individual study protocols and datasets
- **Database files**: Brainstorm database configuration files  
- **Raw data**: MEG/EEG/MRI/PET source files
- **Results**: Processed analysis outputs

## Database Structure

Follow Brainstorm's standard database organization:
```
data/
├── protocol1/
│   ├── data/
│   ├── anat/
│   └── brainstormdb.mat
├── protocol2/
└── ...
```

Refer to the [Brainstorm database tutorial](https://neuroimage.usc.edu/brainstorm/Tutorials/CreateProtocol) for proper database setup.
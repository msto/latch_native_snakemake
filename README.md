# Latch native Snakemake workflow

Latch offers native Snakemake support. 
This repository contains a minimal Snakemake workflow and Latch metadata to demonstrate this functionality.

## Summary

The pipeline runs a short two-step scatter-gather over a list of samples provided via an input samplesheet.
This example is intended to test the ability to load a sample manifest during Latch's JIT, and to use input functions to link metadata provided in the samplesheet to actual file paths on Latch.


## Latch docs

https://wiki.latch.bio/docs/snakemake/quickstart
https://wiki.latch.bio/docs/snakemake/tutorial

## Running the pipeline locally

Clone the repo, create and activate the conda environment, and run the pipeline.

```console
git clone git@github.com:msto/latch_native_snakemake.git
cd latch_native_snakemake

mamba env create -f environment.yml
mamba activate latch_native_snakemake

snakemake -j1
```

## Running the pipeline on Latch

Within the working directory, and with the `latch_native_snakemake` environment activated, register the workflow.

```console
latch register . --snakefile Snakefile
```

## Notes on preparing the pipeline for use on Latch

Following the instructions in the quickstart and tutorial, I generated metadata and a Dockerfile with the Latch CLI.

```console
latch generate-metadata config.yml --snakemake
latch dockerfile . --snakemake
```

I made the following modifications to the default file contents:
- `latch_metadata/parameters.py`: I set `download=True` for the `metadata_tsv` parameter, so the list of input samples can be loaded during Latch's JIT ([per the docs](https://wiki.latch.bio/docs/snakemake/quickstart#file-metadata))
  https://github.com/msto/latch_native_snakemake/blob/f55851f22151ade56317406ae114e296b641587b/latch_metadata/parameters.py#L32
- `latch_metadata/__init__.py`: I set appropriate values for the metadata
  https://github.com/msto/latch_native_snakemake/blob/f55851f22151ade56317406ae114e296b641587b/latch_metadata/__init__.py#L7-L11
- `Dockerfile`: I update the conda environment created by the Dockerfile to include the additional dependencies specified in my `environment.yml`
  https://github.com/msto/latch_native_snakemake/blob/f55851f22151ade56317406ae114e296b641587b/Dockerfile#L55
- `.dockerignore`: I set up an allowlist limited to the workflow and Latch files.
- https://github.com/msto/latch_native_snakemake/blob/f55851f22151ade56317406ae114e296b641587b/.dockerignore#L1-L15

# hpc-scripts

This is a loose collection scripts written to be run on HPCs with a SLURM scheduler. To the people of the future, these scripts were probably only useful at a certain time and at a certain place.

# Files

## rapid_curation

  bash scripts to run rapid curation https://gitlab.com/wtsi-grit/rapid-curation/ outside of their pipeline

## 3D-DNA_JBAT.sbatch

  3D-DNA JBAT curation, after producing edits in Juicebox and a *.review.asembly file

## 3D-DNA.sbatch

  Run the 3D-DNA assembly pipeline with "-r 0" option as default

## compress_logs.sh

  search for analysis job logs and results then tarball them

## slurm_jobutil.sh

  Outputs various perfomance stats for your slurm sbatch job

## juicer.sbatch

  Run Juicer Hi-C pre-processing, stop early before .hic generation

## pairtools.sbatch

  Run Hi-C QC pipeline ala. https://omni-c.readthedocs.io/en/latest/ from Dovetail Genomics using mainly pairtools

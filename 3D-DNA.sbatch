#!/bin/bash -l
#SBATCH -A <your account>
#SBATCH -p core
#SBATCH -n 16
#SBATCH -t 10-00:00:00
#SBATCH -J 3ddna.job
#SBATCH -o 3ddna.out
#SBATCH -e 3ddna.err
#SBATCH --mail-user remi-andre.olsen@scilifelab.se
#SBATCH --mail-type=ALL

set -e

in_ref=/path/to/input_assembly.fa
mnd=/path/to/juicer/aligned/merged_nodups.txt

# singularity pull docker://remiolsen/3d-dna-docker:20211125
sif="singularity exec 3d-dna-docker_20211125.sif" 

# NOTE! This will run 3D-DNA without extensive error correction. Many times this is the superior way
$sif run-asm-pipeline.sh --build-gapped-map -r 0 $in_ref $mnd 

# Some extremely rudimentary assembly validation follows:
# module load quast
# module load multiqc
# quast.py --eukaryote --threads 16 $in_ref /path/to/3D-DNA/*.FINAL.fasta
# multiqc -m quast -o . -i Assembly_evaluation /path/to/quast_run/ 
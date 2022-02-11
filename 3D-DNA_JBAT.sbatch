#!/bin/bash -l
#SBATCH -A <your account> 
#SBATCH -p core
#SBATCH -n 8
#SBATCH -t 2-00:00:00
#SBATCH -J 3ddna_JBAT.job
#SBATCH -o 3ddna_JBAT.out
#SBATCH -e 3ddna_JBAT.err
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL

set -e

# The .assembly file would be created in juicebox from your manual curation
asm=/path/to/your/assembly.rawchrom.review.assembly
in_ref=/path/to/input_contig_assembly.fasta
mnd=/path/to/juicer/aligned/merged_nodups.txt

# singularity pull docker://remiolsen/3d-dna-docker:20211125
sif="singularity exec 3d-dna-docker_20211125.sif" 

$sif run-asm-pipeline-post-review.sh -r $asm $in_ref $mnd 

# Some extremely rudimentary assembly validation follows:
# module load quast
# module load multiqc
# quast.py --eukaryote --threads 16 $in_ref /path/to/3D-DNA/*.FINAL.fasta /path/to/3D-DNA_review/*.FINAL.fasta
# multiqc -m quast -o . -i Assembly_evaluation /path/to/quast_run/ 
#!/bin/bash -l
#SBATCH -A <your project>
#SBATCH -o rc_gap.out
#SBATCH -e rc_gap.err
#SBATCH -J rc_gap.job
#SBATCH -p node -n 4
#SBATCH -t 1-00:00:00
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL
#SBATCH --qos=normal

set -f
# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rg="singularity exec runGap.sif"

ref=contig_asm.fasta
outprefix="sample1"
cores=4
# Made in first step
genome=sample1.genome

$rg seqtk cutN -n 1 -g $ref > ${outprefix}.gap.bed
$rg /scripts/getbg.sh ${outprefix}.gap.bed > ${outprefix}.gap.bedgraph
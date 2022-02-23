#!/bin/bash -l
#SBATCH -A <your project>
#SBATCH -o rc_rep.out
#SBATCH -e rc_rep.err
#SBATCH -J rc_rep.job
#SBATCH -p node -n 4
#SBATCH -t 1-00:00:00
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL
#SBATCH --qos=normal

set -f
# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rr="singularity exec runRepeat.sif"

ref=contig_asm.fasta
outprefix="sample1"
cores=4
# Made in first step
genome=sample1.genome
binsize=10000

$rr /software/windowmasker  -mk_counts -in $ref -out ${outprefix}.stage1
$rr /software/windowmasker  -ustat ${outprefix}.stage1 -in $ref -out ${outprefix}.wm -dust true
$rr /scripts/extract_repeat.pl ${outprefix}.wm > ${outprefix}.repeat.bed

$rr bedtools makewindows -g $genome -w $binsize > ${outprefix}.bin.bed
$rr bedtools intersect -a ${outprefix}.bin.bed -b ${outprefix}.repeat.bed | $rr /scripts/reformat.sh | sort -k1 -V > ${outprefix}.intersect.bed

cat ${outprefix}.intersect.bed | sort -k1 -V > ${outprefix}.sorted_intersect.bed
cat ${outprefix}.bin.bed | $rr bedtools map -a - -b ${outprefix}.sorted_intersect.bed -c 4 -o sum -g $genome > ${outprefix}.density.bed

sort -k2,2 -nr $genome > sorted.genome
$rr /scripts/replace.sh ${outprefix}.density.bed > ${outprefix}.density_nodot.bed
$rr bedGraphToBigWig ${outprefix}.density_nodot.bed sorted.genome ${outprefix}.repeat_density.bw
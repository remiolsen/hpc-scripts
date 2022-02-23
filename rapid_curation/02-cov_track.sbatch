#!/bin/bash -l
#SBATCH -A <your account>
#SBATCH -o rc_cov.out
#SBATCH -e rc_cov.err
#SBATCH -J rc_cov.job
#SBATCH -p node -n 4 
#SBATCH -t 1-00:00:00
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL
#SBATCH --qos=normal

set -f

# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rc="singularity exec runCoverage.sif"

ref=contig_asm.fasta

# PacBio input files as a list, eg:
# reads1.bam
# reads2.bam
# reads3.bam
pac_fofn=fofn.txt
outprefix="sample1"
cores=16
# Made in previous step
genome=sample1.genome

# Index ref
mkdir in_ref; cd in_ref; ln -s $ref
ln_ref=$PWD/`basename $ref`
$rc minimap2 -d ${ln_ref}.mmi $ln_ref
cd ..

# mm2 mapping
pnum=0
for f in $(cat $pac_fofn);
do 
	$rc samtools fastq $f | $rc minimap2 --MD -t $cores -a ${ln_ref}.mmi - | $rc samtools view -Sb - > ${outprefix}.part_${pnum}.bam
	let pnum++
done

# merge, sort, make pri bam files
$rc samtools merge -f ${outprefix}.merged.bam ${outprefix}.part_*.bam 
$rc samtools sort -T sort_tmp -o ${outprefix}.merged.sorted.bam ${outprefix}.merged.bam
$rc samtools view -b -hF 256 ${outprefix}.merged.sorted.bam > ${outprefix}.primary.bam

# cleanup 
rm *.part_*.bam *.merged.bam *.merged.sorted.bam

# Make bed and wig
$rc bamToBed -i ${outprefix}.primary.bam | sort -k1,1 -T sort_tmp > ${outprefix}.geval.bed
$rc genomeCoverageBed -bga -split -i ${outprefix}.geval.bed -g $genome | sort -k1,1 -k2,2n > ${outprefix}.coverage.bed
$rc bedGraphToBigWig ${outprefix}.coverage.bed $genome ${outprefix}.coverage.bw


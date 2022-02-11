#!/bin/bash -l
#SBATCH -A <your account>
#SBATCH -p core
#SBATCH -n 16
#SBATCH -t 10-00:00:00
#SBATCH -J preproc.job
#SBATCH -o preproc.out
#SBATCH -e preproc.err
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL

# UPPMAX specific dependencies. YMMV
module load bioinfo-tools
module load bwa
module load samtools
module load preseq
module load python/3.7.2

# singularity pull docker://quay.io/biocontainers/pairtools:0.3.0--py37hb9c2fc3_5
pt="singularity exec pairtools_0.3.0--py37hb9c2fc3_5.sif pairtools"

ref=/path/to/ref.fa 
fq1=/path/to/R1_001.fastq.gz
fq2=/path/to/R2_001.fastq.gz
outprefix="sample1"
rg="sample1"
cores=16

# Get Dovetail script to parse pairtools output 
# git clone https://github.com/dovetail-genomics/Omni-C.git
SRCDIR=`readlink -e Omni-C/`

# Essentially taken from https://omni-c.readthedocs.io/en/latest/library_qc.html
# Would possibly work for traditional Hi-C, Micro-C and HiCHiP

samtools faidx ${ref}
cut -f1,2 ${ref}".fai" > ${outprefix}".genome"
genome=${outprefix}".genome"
bwa mem -5SP -T0 -t${cores} \
    -R "@RG\tID:$rg\tSM:$rg\tLB:$rg\tPL:ILLUMINA\tPU:none" \
    $ref \
    $fq1 \
    $fq2 \
| $pt parse \
	--chroms-path ${genome} \
	--min-mapq 30 \
	--output-stats out.stats \
	--walks-policy 5unique \
	--max-inter-align-gap 50 \
      	--nproc-in ${cores} --nproc-out ${cores} \
| $pt sort  \
	--nproc ${cores} \
| $pt dedup \
	--nproc-in ${cores} --nproc-out ${cores} \
	--mark-dups  \
 	--output-stats ${outprefix}-PT.stats.txt \
	--output-dups - \
| $pt split \
	--nproc-in ${cores} --nproc-out ${cores} \
	--output-pairs ${outprefix}.PT.pairs.gz  \
	--output-sam - \
| samtools view -bS - \
| samtools sort -@${cores} - -o ${outprefix}-PT.bam

samtools index ${outprefix}-PT.bam;

# Optional
preseq lc_extrap -B -o $outprefix.preseq ${outprefix}-PT.bam

${SRCDIR}/get_qc.py -p ${outprefix}-PT.stats.txt -d ${outprefix}.preseq
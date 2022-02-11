#!/bin/bash -l
#SBATCH -A <your account> 
#SBATCH -p core
#SBATCH -n 16
#SBATCH -t 3-00:00:00
#SBATCH -J juicer.job
#SBATCH -o juicer.out
#SBATCH -e juicer.err
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL

set -e

#
# This will run Juicer for pre-processing of Hi-C data
# NOTE! As it is now it should only be used for DNAse Hi-C (e.g., OmniC from Dovetail Genomics)
#

in_ref=/path/to/input_assembly.fa
r1=R1_001.fastq.gz
r2=R2_001.fastq.gz

# singularity pull docker://remiolsen/juicer-cpu-docker:20211125
sif="singularity exec juicer-cpu-docker_20211125.sif"

# softlink reference, make indices
mkdir in_ref; cd in_ref; ln -s $in_ref
ln_ref=$PWD/`basename $in_ref`
$sif samtools faidx $ln_ref
$sif bwa index $ln_ref

# Make chrom.sizes
cut -f1,2 ${ln_ref}".fai" > ../chrom.sizes

cd ..

# softlink reads
mkdir fastq; cd fastq
ln -s $r1
ln -s $r2
cd ..

# run juicer
$sif juicer.sh -t 16 -p chrom.sizes -s none -S early -z $ln_ref 

# cleanup
rm -r splits
mkdir aligned_clean
mv aligned/merged_nodups.txt aligned_clean/
mv aligned/inter*.txt aligned_clean
rm -r aligned

# Optional - filter contacts by MapQ>=30
# awk '{if($9 > 29 && $12 > 29){print $0}}' aligned_clean/merged_nodups.txt > aligned_clean/merged_nodups_mq30.txt

# Optional 2 - convert data to .bed format for salsa2 scaffolding. Will use 16 cores by default
# git clone https://github.com/remiolsen/merged_nodups2bed
# sh merged_nodups2bed/merged_nodups2bed.sh -i /path/to/juicer/aligned/merged_nodups.txt -o output_
#!/bin/bash -l
#SBATCH -A <your project>
#SBATCH -o rc_telo.out
#SBATCH -e rc_telo.err
#SBATCH -J rc_telo.job
#SBATCH -p node -n 4 
#SBATCH -t 1-00:00:00
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL
#SBATCH --qos=normal

set -f
# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rt="singularity exec runTelo.sif"
# find your telomere motif here, https://github.com/tolkit/a-telomeric-repeat-database/tree/main/data/curated
teloseq="AACCCT"


ref=candidate_scaff.fasta
ref_tmp=`basename $ref`
ref_base=${ref_tmp%.*}
outprefix="sample1"
cores=4
# Made in first step
genome=/path/to/${outprefix}.genome
#export SINGULARITYENV_PATH=/opt/conda/envs/rapid_curation/bin
export SINGULARITYENV_LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/:/usr/lib/gcc/x86_64-linux-gnu/7.4.0
export SINGULARITYENV_VGP_PIPELINE=/software/pipeline

$rt /pipelines/telomere/find_telomere.sh $ref $teloseq $PWD
$rt /scripts/get_telomere_result.sh  $PWD/${ref_base}.windows $PWD/${outprefix}_telomere.bed $PWD/${outprefix}_telomere.bedgraph
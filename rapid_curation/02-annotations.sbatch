#!/bin/bash -l
#SBATCH -A <your account>
#SBATCH -o rc_annotation.out
#SBATCH -e rc_annotation.err
#SBATCH -J rc_annotation.job
#SBATCH -p core -n 4 
#SBATCH -t 1-00:00:00
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL
#SBATCH --qos=normal

set -e

## Input parameters

# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rc="singularity exec runCoverage.sif"
rr="singularity exec runRepeat.sif"
rg="singularity exec runGap.sif"
rt="singularity exec runTelo.sif"

# singularity pull docker://remiolsen/rapidcuration_extras:20220629
re="singularity exec rapidcuration_extras_20220629.sif"

# For telo finder script
export PATH="/path/to/jellyfish/:$PATH"

pac_fofn=fofn.txt
# PacBio input files as a list, eg:
# reads1.bam
# reads2.bam
# reads3.bam
ref=candidate_scaff.fasta
outprefix="sample1"
cores=16
# Made in previous step
genome=/path/to/${outprefix}.genome
# Repeats
binsize=10000
# find your telomere motif here, https://github.com/tolkit/a-telomeric-repeat-database/tree/main/data/curated
teloseq="AACCCT"
# Example: found using telo finder script
#teloseq="AAGAG"

# 1) Coverage track

# Index ref
mkdir in_ref; cd in_ref; ln -s $ref
ln_ref=$PWD/`basename $ref`
$rc minimap2 -d ${ln_ref}.mmi $ln_ref
cd ..

# mm2 mapping
pnum=0
for f in $(cat $pac_fofn);
do 
	$rc samtools fastq $f | $rc minimap2 --MD -t $cores -a ${ln_ref} - | $rc samtools view -Sb - > ${outprefix}.part_${pnum}.bam
	let pnum++
done

printf '%s\n' *.part_*.bam > inputbams.fofn

# merge, sort, make pri bam files
$rc samtools merge -b inputbams.fofn -f ${outprefix}.merged.bam 
$rc samtools sort -T sort_tmp -o ${outprefix}.merged.sorted.bam ${outprefix}.merged.bam
$rc samtools view -b -hF 256 ${outprefix}.merged.sorted.bam > ${outprefix}.primary.bam

# cleanup 
rm *.part_*.bam *.merged.bam *.merged.sorted.bam

# Use HiC data and bwa mem mapping from previous step
ln -s ${outprefix}-PT.bam ${outprefix}.primary.bam

# Make bed and wig
$rc bamToBed -i ${outprefix}.primary.bam | sort -k1,1 > ${outprefix}.geval.bed
$rc genomeCoverageBed -bga -split -i ${outprefix}.geval.bed -g $genome | sort -k1,1 -k2,2n > ${outprefix}.coverage.bed
$rc bedGraphToBigWig ${outprefix}.coverage.bed $genome ${outprefix}.coverage.bw

## 2) Repeat density track

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

## 3) Gap track 

# Note 2022-06-29 Might give invalid bedgraph file. Ivestigate

$rg seqtk cutN -n 1 -g $ref > ${outprefix}.gap.bed
$rg /scripts/getbg.sh ${outprefix}.gap.bed > ${outprefix}.gap.bedgraph

## 4) Telomere track

ref_tmp=`basename $ln_ref`
ref_base=${ref_tmp%.*}

# Note 2022-06-29. Callin the baked in script inside the "runtelo" images does not seem to work
# For now copy the scripts to analysis folder
# $rt cp /pipelines/telomere/find_telomere.sh .
# $rt cp /pipelines/telomere/telomere.jar .
# /scripts/get_telomere_result.sh
# /pipelines/telomere/find_telomere 

#export SINGULARITYENV_PATH=/opt/conda/envs/rapid_curation/bin
#export SINGULARITYENV_LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/:/usr/lib/gcc/x86_64-linux-gnu/7.4.0
#export SINGULARITYENV_VGP_PIPELINE=/software/pipeline

#$rt /pipelines/telomere/find_telomere.sh $ln_ref $teloseq $PWD
#$rt /scripts/get_telomere_result.sh  $PWD/${ref_base}.windows $PWD/${outprefix}_telomere.bed $PWD/${outprefix}.telomere.bedgraph

./find_telomere.sh $ln_ref $teloseq $PWD

# Note. GRIT script outputs a broken bedgraph
awk 'BEGIN{OFS="\t"}{print $1,$2,$3,$4,$5,int($6*100)}' $PWD/${ref_base}.windows > $PWD/${ref_base}.fixed.windows

./get_telomere_result.sh  $PWD/${ref_base}.fixed.windows $PWD/${outprefix}_telomere.bed $PWD/${outprefix}.telomere.bedgraph

# Use the new telomer script in tandem, rerun above as needed
$re python $telo_finder $ln_ref

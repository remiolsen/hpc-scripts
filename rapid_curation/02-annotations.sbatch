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

set -f

## Input parameters

# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rc="singularity exec runCoverage.sif"
rr="singularity exec runRepeat.sif"
rg="singularity exec runGap.sif"
rt="singularity exec runTelo.sif"

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

## 1) Coverage track

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

$rg seqtk cutN -n 1 -g $ref > ${outprefix}.gap.bed
$rg /scripts/getbg.sh ${outprefix}.gap.bed > ${outprefix}.gap.bedgraph

## 4) Telomere track

ref_tmp=`basename $ref`
ref_base=${ref_tmp%.*}

#export SINGULARITYENV_PATH=/opt/conda/envs/rapid_curation/bin
export SINGULARITYENV_LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/:/usr/lib/gcc/x86_64-linux-gnu/7.4.0
export SINGULARITYENV_VGP_PIPELINE=/software/pipeline

# check this prefix
$rt /pipelines/telomere/find_telomere.sh $ref $teloseq $PWD
$rt /scripts/get_telomere_result.sh  $PWD/${ref_base}.windows $PWD/${outprefix}_telomere.bed $PWD/${outprefix}.telomere.bedgraph

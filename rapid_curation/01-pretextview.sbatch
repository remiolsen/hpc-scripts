#!/bin/bash -l
#SBATCH -A <your project>
#SBATCH -o rc_pretext.out
#SBATCH -e rc_pretext.err
#SBATCH -J rc_pretext.job
#SBATCH -p node -n 16 
#SBATCH -t 2-00:00:00
#SBATCH --mail-user <your email>
#SBATCH --mail-type=ALL
#SBATCH --qos=normal

# singularity pull <docker from http://bioconda.github.io/recipes/pairtools/README.html>
pt="singularity exec pairtools_0.3.0--py38h8582fc7_4.sif pairtools"
# https://gitlab.com/wtsi-grit/rapid-curation/-/tree/main/rapid_hic_software
rh="singularity exec runHiC.sif"

ref=candidate_scaff.fasta
fq1=R1_001.fastq.gz
fq2=R2_001.fastq.gz
outprefix="sample1"
rg="sample1"
cores=16

# Adapted to IRMA, change if necessary
export SINGULARITY_BIND="/lupus:/lupus"

## 1 pairtools for mapping and deduping (instead of arima pipe)

# softlink reference, make indices
mkdir in_ref; cd in_ref; ln -s $ref
ln_ref=$PWD/`basename $ref`
$rh samtools faidx $ln_ref
$rh bwa index $ln_ref
cd ..

cut -f1,2 ${ln_ref}".fai" > ${outprefix}".genome"
genome=${outprefix}".genome"
ptbam=${outprefix}-PT.bam
$rh bwa mem -5SP -T0 -t${cores} \
    -R "@RG\tID:$rg\tSM:$rg\tLB:$rg\tPL:ILLUMINA\tPU:none" \
    $ln_ref \
    $fq1 \
    $fq2 \
| $pt parse \
	--chroms-path ${genome} \
	--min-mapq 30 \
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
| $rh samtools view -bS - \
| $rh samtools sort -@${cores} - -o $ptbam 


$rh samtools index $ptbam

## 2 bam2bed
ptbed=${outprefix}-PT.bed
$rh samtools view -@4 -u -F0x400 $ptbam | $rh bamToBed | sort -k4 --parallel=8 -S50G > $ptbed
 
## 3 HiGlass start
prebed=${outprefix}.pre.bed
cat $ptbed | $rh paste -d '\t' - - | $rh sed 's/-/_/g' | $rh awk 'BEGIN {FS="\t"; OFS="\t"} {if(NF>=12){ if ($1 > $7) {print substr($4,1,length($4)-2),$12,$7,$8,"16",$6,$1,$2,"8",$11,$5} else { print substr($4,1,length($4)-2),$6,$1,$2,"8",$12,$7,$8,"16",$5,$11} }}' | $rh tr '\-+' '01'  | $rh sort --parallel=8 -S10G -k3,3d -k7,7d > $prebed

## 4 HiGlass end
outcool=${outprefix}.cool
outmcool=${outprefix}.mcool
$rh cooler cload pairs -0 -c1 3 -p1 4 -c2 7 -p2 8 $genome:1000 $prebed $outcool 
$rh cooler zoomify -o $outmcool $outcool 

## 5 Pretext
outpretext=${outprefix}.pretext
$rh samtools view -h $ptbam | $rh PretextMap -o $outpretext --sortby length --mapq 0
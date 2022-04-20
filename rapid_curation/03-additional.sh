#!/bin/bash -l

# singularity pull docker://remiolsen/rapidcuration_extras:20220223
re="singularity exec rapidcuration_extras_20220223.sif"
outprefix="sample1"
ref=candidate_scaff.fasta

# git clone https://gitlab.com/wtsi-grit/rapid-curation.git
# Note 2022-02-25. These scripts might contain some hardcoded paths that need to be manually edited.
rc=/path/to/rapid-curation/

## Note! this file is more of a cookbook than a script or a pipeline.
## Use with caution and read the rapid curation documentation first

# 1) Add annotations to pretextview file
annotation_folder="/path/to/annotation"

$re bigWigToBedGraph ${annotation_folder}/${outprefix}.coverage.bw /dev/stdout | $re PretextGraph -i ${annotation_folder}/${outprefix}.pretext -n "coverage" -o ${outprefix}.annotated.pretext
$re bigWigToBedGraph ${annotation_folder}/${outprefix}.repeat_density.bw /dev/stdout | $re PretextGraph -i ${outprefix}.annotated.pretext -n "repeat density" 
cat ${annotation_folder}/${outprefix}.gap.bedgraph | $re PretextGraph -i ${outprefix}.annotated.pretext -n "gaps"
cat ${annotation_folder}/${outprefix}.telomere.bedgraph | $re PretextGraph -i ${outprefix}.annotated.pretext -n "telomeres"

# 2 ) Process pretext AGP files

in_agp = "/path/to/pretextview.agp"
ln -s $ref
baseref=`basename $ref`
$re perl ${rc}/rapid_split.pl -fa ${baseref} 

$re python ${rc}/rapid_pretext2tpf_XL.py ${baseref}.tpf $in_agp

$re perl ${rc}/rapid_join.pl -fa ${ref} -tpf rapid_prtxt_XL.tpf -csv input.csv -out ${outprefix}.curated

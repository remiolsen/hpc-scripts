# Searches a path a path for potential log files, scripts and some results then makes a tarball of it. Useful for archiving analysis folders
# Usage: compress_logs analysis_folder/
# Stick this in your .bashrc 
function compress_logs() {
    trim_path=$(echo $1 | sed 's:/*$::')
    find $trim_path -type f -iregex '.*\.\(err\|out\|stdOut\|stdErr\|pdf\|yaml\|yml\|xml\|json\|md\|settings\|txt\|log\|html\|tsv\|csv\|slurm\|sbatch\|sh\|py\|R\|conf\|config\|ini\)$' -size -10M -print0 | tar -czvf ${trim_path}.tar.gz --null -T -
    return 0
}
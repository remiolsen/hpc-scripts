# jobutil <jobID>
# - Outputs various perfomance stats for your slurm sbatch job
# - the efficiency of your job is the ratio between CPUtime (elapsed time * requested CPUS) and what I believe is the measured non-idle CPU time (“avecpu”)
# - Stick this in your .bashrc
function jobutil() {
   sacct --units=G -j $1.batch --format=jobid,MaxRSS,MaxVMSize,avevmsize,end,elapsed,cputime,avecpu,AllocCPUS,NodeList,AveDiskRead,AveDiskWrite
}

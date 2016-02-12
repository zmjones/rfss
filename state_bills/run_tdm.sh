#PBS -l nodes=1:ppn=1
#PBS -l walltime=24:00:00
#PBS -l pmem=8gb
#PBS -mae
#PBS -M fridolin.linder@gmail.com
#PBS -j oe

cd $PBS_O_WORKDIR
module load python
python make_bigram_tdm.py

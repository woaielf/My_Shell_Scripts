#!/bin/bash
set -e 
set -u 

# need to set
sample=1-1
working_dir=/media/hobart/soma
fq_dir=/media/hobart/soma/01_clean_phred33

sam_dir=${working_dir}/${sample}/02_bwa
mkdir -p ${sam_dir}

index=/media/hobart/backup/01_ref/ucsc/hg38/BWA_index/hg38


for lane in 1 2 3
do
	filename=${sample}-${lane}
	group='@RG\tID:${filename}\tSM:Autism\tPL:ILLUMINA'
	date -In
	echo "begin to mapping ${filename}"
	fq1=${fq_dir}/${filename}_1.phred33.fq.gz
	fq2=${fq_dir}/${filename}_2.phred33.fq.gz
	bwa mem -t 30 -M -R ${group} ${index} ${fq1} ${fq2} 1>${sam_dir}/${filename}.sam 2>${sam_dir}/${filename}.bwa.log
done
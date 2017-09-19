#!/bin/bash
set -e 
set -u 

sample=1-1
ori_file=/media/hobart/soma/01_clean_phred33
dest_file=

for lane in 1 2 3
do
	for end in 1 2
	do 
		cp ${ori_file}/${sample}-${lane}_${end}.phred33.fq.gz ${dest_file}
		echo "file is copied: ${sample}-${lane}_${end}.phred33.fq.gz"
	done 
done
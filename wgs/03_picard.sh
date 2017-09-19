#!/bin/bash
set -e 
set -u 

# picard: SortSam & MarkDuplicates & FixMateInfo
# samtools: flagstat & stats & index
# Goal: map → SortSam → flagstat & stats → MarkDuplicates & FixMateInfo → index

# need to set
# input like '1-1-1'
sample=$1
working_dir=/media/hobart/soma

# 
sam_dir=${working_dir}/${sample}/02_bwa
bam_dir=${working_dir}/${sample}/03_picard

mkdir -p ${bam_dir}

# tools
PICARD=/media/hobart/backup/02_software/picardtools/2.9.2/picard.jar


#####################################################
################ Step 2: Sort and Index #############
#####################################################

echo output-----SortSam `date -In`
java -jar $PICARD SortSam SORT_ORDER=coordinate INPUT=${sam_dir}/${sample}.sam OUTPUT=${bam_dir}/${sample}.bam 
# add index
samtools index ${bam_dir}/${sample}.bam
echo output-----SortSam `date -In`

#####################################################
################ Step 3: Basic Statistics ###########
#####################################################

echo output-----stats `date -In`
samtools flagstat ${bam_dir}/${sample}.bam > ${bam_dir}/${sample}.alignment.flagstat
samtools stats  ${bam_dir}/${sample}.bam > ${bam_dir}/${sample}.alignment.stat
# echo plot-bamstats -p ${sample}_QC  ${sample}.alignment.stat
echo output-----stats `date -In`

#####################################################
####### Step 4: multiple filtering for bam files ####
#####################################################

###MarkDuplicates###

echo output-----MarkDuplicates `date -In`
java -jar $PICARD MarkDuplicates \
INPUT=${bam_dir}/${sample}.bam OUTPUT=${bam_dir}/${sample}_marked.bam METRICS_FILE=${sample}.metrics
echo output-----MarkDuplicates `date -In`

###FixMateInfo###

echo output-----FixMateInfo `date -In`
java -jar $PICARD FixMateInformation \
INPUT=${bam_dir}/${sample}_marked.bam OUTPUT=${bam_dir}/${sample}_marked_fixed.bam SO=coordinate  
echo output-----FixMateInfo `date -In`

# add index
samtools index ${bam_dir}/${sample}_marked_fixed.bam
# !!!!!!!!!!remember to delete the files 
# rm ${sample}.sam ${sample}.bam ${sample}_marked.bam

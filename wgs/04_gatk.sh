#!/bin/bash
set -e
set -u

# changed files
sample=$1
working_dir=/media/hobart/soma


infile=${working_dir}/${sample}/03_picard
data_deal=${working_dir}/${sample}/04_gatk

mkdir -p ${data_deal}
cd ${data_deal}

# files required
genome=/media/hobart/backup/01_ref/ucsc/hg38/hg38.fasta
index=/media/hobart/backup/01_ref/ucsc/hg38/BWA_index/hg38
bundle=/media/hobart/backup/03_vcf_gatk/hg38

# tools
GATK=/media/hobart/backup/02_software/gatk/GenomeAnalysisTK.jar
PICARD=/media/hobart/backup/02_software/picardtools/2.9.2/picard.jar

# variation annotation files
DBSNP=${bundle}/dbsnp_138.hg38.vcf
KG_SNP=${bundle}/1000G_phase1.snps.high_confidence.hg38.vcf
KG_indels=${KG_SNP}
Mills_indels=${bundle}/Mills_and_1000G_gold_standard.indels.hg38.vcf
Hapmap=${bundle}/hapmap_3.3.hg38.vcf
Axiom=${bundle}/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf
Omni=${bundle}/1000G_omni2.5.hg38.vcf


#1

echo ---------------------------------------
echo "begin #1:RealignerTargetCreator `date -In`"

java -jar $GATK \
-T RealignerTargetCreator \
-I ${infile}/${sample}_marked_fixed.bam \
-R $genome \
-o ${data_deal}/${sample}_target.intervals \
-known $Mills_indels \
-known $KG_indels \
-nt 30


#2

echo ---------------------------------------
echo "begin #2:IndelRealigner `date -In`"

java -jar $GATK \
-T IndelRealigner \
-I ${infile}/_marked_fixed.bam \
-R $genome \
-targetIntervals ${data_deal}/${sample}_target.intervals \
-o ${data_deal}/${sample}_realigned.bam \
-known $Mills_indels \
-known $KG_indels

#3

echo ---------------------------------------
echo "begin #3:BaseRecalibrator `date -In`"

java -jar $GATK \
-T BaseRecalibrator \
-I ${data_deal}/${sample}_realigned.bam \
-R $genome \
-o ${data_deal}/${sample}_temp.table \
-knownSites $Mills_indels \
-knownSites $KG_indels \
-knownSites $DBSNP

#4

echo ---------------------------------------
echo "begin #4:PrintReads `date -In`"

java -jar $GATK \
-T PrintReads \
-R $genome \
-I ${data_deal}/${sample}_realigned.bam \
-o ${data_deal}/${sample}_recal.bam \
-BQSR ${data_deal}/${sample}_temp.table

samtools index -@ 30 ${data_deal}/${sample}_recal.bam

#5
#bgi
echo ----------------------------------
echo "begin #5:HaplotypeCaller `date -In`"

java -jar $GATK -T HaplotypeCaller \
-R $genome --genotyping_mode DISCOVERY \
-I ${data_deal}/${sample}_recal.bam \
-o ${data_deal}/raw_variants.vcf -stand_call_conf 30 -minPruning 3

#6 SNP

echo ----------------------------------
echo "begin #6-1:SelectVariants `date -In`"

java -jar $GATK -T SelectVariants \
-R $genome \
-V ${data_deal}/raw_variants.vcf -selectType SNP \
-o ${data_deal}/raw_snps.vcf

echo ----------------------------------
echo "begin #6-2:VariantRecalibrator `date -In`"

java -jar $GATK -T VariantRecalibrator \
-R $genome -input ${data_deal}/raw_snps.vcf \
-resource:hapmap,known=false,training=true,truth=true,prior=15.0 ${Hapmap} \
-resource:omni,known=false,training=true,truth=true,prior=12.0 ${Omni} \
-resource:1000G,known=false,training=true,truth=false,prior=10.0 ${KG_SNP} \
-resource:dbsnp,known=true,training=false,truth=false,prior=2.0 ${DBSNP} \
-an DP -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum \
-mode SNP \
-tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
-recalFile ${data_deal}/recalibrate_SNP.recal \
-tranchesFile recalibrate_SNP.tranches
# -rscriptFile recalibrate_SNP_plots.R

echo ----------------------------------
echo "begin #6-3:ApplyRecalibration `date -In`"

java -jar $GATK -T ApplyRecalibration \
-R $genome \
-input ${data_deal}/raw_snps.vcf \
-mode SNP \
--ts_filter_level 99.0 \
-recalFile ${data_deal}/recalibrate_SNP.recal \
-tranchesFile recalibrate_SNP.tranches \
-o ${data_deal}/filtered_snp.vcf

#7 Indel
echo ----------------------------------
echo "begin #7-1:SelectVariants `date -In`"

java -jar $GATK -T SelectVariants \
-R $genome \
-V ${data_deal}/raw_variants.vcf -selectType INDEL \
-o ${data_deal}/raw_indels.vcf

echo ----------------------------------
echo "begin #7-2:VariantRecalibrator `date -In`"

java -jar $GATK -T VariantRecalibrator \
-R $genome -input ${data_deal}/raw_indels.vcf \
-resource:mills,known=true,training=true,truth=true,prior=12.0 ${KG_indels} \
-an QD -an DP -an FS -an SOR -an MQRankSum -an ReadPosRankSum -mode INDEL \
-tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 --maxGaussians 4 \
-recalFile ${data_deal}/recalibrate_INDEL.recal \
-tranchesFile recalibrate_INDEL.tranches
#-rscriptFile recalibrate_INDEL_plots.R

echo ----------------------------------
echo "begin #7-3:ApplyRecalibration `date -In`"

java -jar $GATK -T ApplyRecalibration \
-R ${genome} \
-input ${data_deal}/raw_indels.vcf \
-mode INDEL \
--ts_filter_level 99.0 \
-recalFile ${data_deal}/recalibrate_INDEL.recal \
-tranchesFile recalibrate_INDEL.tranches \
-o ${data_deal}/filtered_indel.vcf
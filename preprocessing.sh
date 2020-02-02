#!/bin/bash
# processing_log.sh

### SET BY USER
startDir=/ssd/stagamak_tmp
bowtieDBdir=/home/micro/stagamak/databases/h_sapiens_bowtie2 # bowtie2 database directory
bowtieDBname=all_GRCh38.p7 # bowtie2 database name
outFormat=fq # set output format (fa/fq)
processors=32 # the number of processors to use for steps that allow parallel processing

cd $startDir
R1s=(`ls *R1*gz`) # get read 1s in directory
R2s=(`ls *R2*gz`) # get read 2s in directory
stop=`expr ${#R1s[@]} - 1` # get last index number
cleanedDir=shotcleaned_${outFormat}s # name directory for shotcleaner output
mkdir -p $cleanedDir # create directory for shotcleaner output
outFormatLong=`echo $outFormat | sed "s/f\([aq]\)/fast\1/"` # fa/fq become fasta/fastq for shotcleaner & metaphlan2

# # FastQC analysis (if you want to separate from shotcleaner)
# /home/micro/stagamak/bin/fastqc -o FastQC_output/ -t $processors *fast[aq].gz --extract

# loop through paired sample reads
shotcleanerDir=/home/micro/sharptot/src/shotcleaner
for i in `seq 0 $stop`; do
    name=`echo ${R1s[$i]%_S[0-9][0-9]*}`
    outDir=${name}_shotcleaner_${outFormat}
    $shotcleanerDir/shotcleaner.pl \
        -1 ${R1s[$i]} \
        -2 ${R2s[$i]} \
        -o $outDir \
        -of $outFormatLong \
        -d $bowtieDBdir \
        -n $bowtieDBname \
        -nproc $processors
    # move shotcleaned output to single directory
    if [ $outFormat == "fq" ]; then
        cp -v ${outDir}/fastq/*gz $cleanedDir
    else
        cp -v ${outDir}/fasta_cleaned/*gz $cleanedDir
    fi
done

# make backups of shotcleaned files just in case
cd $startDir/$cleanedDir
mkdir -p .backup_gzs
cp -v *gz .backup_gzs
cd $startDir

# run shuffling tool (bc fastuniq outputs ordered alphabetically)
/home/micro/stagamak/scripts/randomize.pl $cleanedDir randomized
mv randomized $cleanedDir

cd $startDir/$cleanedDir/randomized

# metaphlan2
metaphlan2Dir=/home/micro/sharptot/src/metaphlan2
mkdir -p metaphlan_profiles
for f in *.gz; do
    rd=`echo $f | grep -o "R[12]"`
    $metaphlan2Dir/metaphlan2.py $f \
        --input_type $outFormatLong \
        --nproc $processors \
        > metaphlan_profiles/${f%_S[0-9][0-9]*}_${rd}_profile.txt
done

cd $startDir/$cleanedDir/randomized/metaphlan_profiles

# renaming the columns in the metaphlan output to inlude 
# 1. a full ID (sample name + read number)
# 2. sample name
# 3. read number
# for use in R
for f in *_profile.txt; do
    rd=`echo $f | grep -o "R[12]"`
    cat $f | sed \
        -e "s/Metaphlan2_Analysis/${f%_profile*}\nSampleID\t${f%_R[12]_profile*}\nRead\t$rd/" \
        -e 's/#Sample/Full/' > ${f%.txt}_reheader.txt
done

# Copy metaphlan results files to local machine and run merge_metaphlan2_results.R

###########################################################################################

# shotmap
### PRACTICE DATA
# NEG_BUFFER_160921_1   (R1 & R2)   10584
# NEG_DNA_KIT_160919_2  (R1 & R2)   33669
# SP045                 (R1 & R2)   3499106
# SP013                 (R1)        7103368
# SP043                 (R1)        15776004

# FROM shotmap.pl
## Note: you may want to set SHOTMAP_LOCAL with the following commands in your shell:
##       export SHOTMAP_LOCAL=/home/yourname/shotmap          (assumes your SHOTMAP directory is in your home directory, change accordingly
##       You can also add that line to your ~/.bashrc so that you don't have ot set SHOTMAP_LOCAL every single time!
startDir=/ssd/stagamak_tmp
cd $startDir/Practice_data

# this loop took 17 min and 6 sec to run
date
for f in *fq.gz; do
    seqtk seq -a $f | gzip > seqtk_output/${f%fq.gz}fa.gz
done
date

# # this loop took 21 min and 58 sec to run
# date
# for f in *fq.gz; do
#     gunzip -c $f > seqret_output/${f%.gz}
#     seqret -sequence seqret_output/${f%.gz} -outseq seqret_output/${f%fq.gz}fa
#     gzip seqret_output/${f%fq.gz}fa
# done
# date

# # this loop took 18 min and 32 sec to run
# date
# for f in *fq.gz; do
#     zcat $f | fastq_to_fasta -Q33 -z -o fastq_to_fasta_output/${f%fq.gz}fa.gz
# done
# date

cd /ssd/stagamak_tmp/Practice_data
processors=80 # bump up from the 32 I used for shotcleaner and metaphlan2
shotmapDB=/ssd/shotmap-search-dbs/KEGG_021515_1M
inFile=NEG_BUFFER_160921_1*R1*fa.gz

# export SHOTMAP_LOCAL=/home/micro/sharptot/src/shotmap
# export PERL5LIB=/home/micro/sharptot/lib/lib/perl5:/home/micro/sharptot/src/shotmap/lib/:$PERL5LIB
# export PERL5LIB=/home/micro/sharptot/perl5/lib/perl5:$PERL5LIB

shotmapDir=/home/micro/sharptot/src/shotmap/scripts
for inFile in *fa.gz; do
    readNum=`echo $inFile | grep -o "R[12]"`
    outDir=${inFile%_S[0-9][0-9]*}_${readNum}_shotmap
    startTime=`date`
    nice -19 $shotmapDir/shotmap.pl \
        -i $inFile \
        -d $shotmapDB \
        -o $outDir \
        --nprocs $processors \
        --class-score 34 \
        --ags-method none
    endTime=`date`
    echo -e "$inFile\t$startTime\t$endTime" >> start_end_times.txt
done

# originally ran --class-score 31.3 on practice set
cd /home/micro/stagamak/fisher_metagenomes/shotcleaned_randomized_fqs
mkdir -p ../shotcleaned_randomized_fas
for f in *fq.gz; do
    echo $f
    seqtk seq -a $f | gzip -v > ../shotcleaned_randomized_fas/${f%fq.gz}fa.gz
done

cd /home/micro/stagamak/fisher_metagenomes/shotcleaned_randomized_fas
ls -1 *fa.gz > fisher_samples_list.txt
mv fisher_samples_list.txt /home/micro/stagamak/fisher_metagenomes
cp home/micro/stagamak/fisher_metagenomes/fisher_samples_list.txt /ssd/stagamak_tmp/shotmap

cd /ssd/stagamak_tmp/shotmap
nice -19 /home/micro/stagamak/scripts/run_shotmap_clean.pl \
    -samples fisher_samples_list.txt \
    -type fisher \
    -p 100 \
    -score 34
###

shotmapOut=/home/micro/stagamak/fisher_metagenomes/shotmap_kegg_ffdb/fisher
abundDir=/home/micro/stagamak/fisher_metagenomes/shotmap_abunds_data
# mkdir -p $abundDir

cd $shotmapOut

for dir in *fa.gz/; do
    echo $dir
    renameDir=${dir}/output/Abundances_renamed
    mkdir $renameDir
    Rn=`echo $dir | grep -o "R[12]"`
    cp -v ${dir}/output/Abundances/* $renameDir
    cd $renameDir
    mv Abundance_Data_Frame_*.tab Abundance_Data_Frame_sample_${dir%_S[0-9][0-9]*}_${Rn}.tab
    batch_rename.sh "*s.tab" .tab _${dir%_S[0-9][0-9]*}_${Rn}.tab
    cp -v *_${dir%_S[0-9][0-9]*}_${Rn}.tab $abundDir
    cd $shotmapOut
done

### Weird Errors

### Stuff to look up


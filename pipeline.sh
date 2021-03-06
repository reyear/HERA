set -vex 

Working_Script=/HWBNAS01/User/leiyang/hera/HERA/
DAZZ_DB=/HWBNAS01/User/leiyang/hera/DAZZ_DB/
DALIGNER=/HWBNAS01/User/leiyang/hera/DALIGNER/
BWA=/HWBNAS01/User/leiyang/hera/bwa/
MINIMAP2=/HWBNAS01/User/leiyang/hera/minimap2/

###
genome_name=HERA

genome_seq=$(( [ -n "$1" ] && [ -f $1 ] && echo $1) || echo "genome.fa")
Corrected_Pacbio=$(( [ -n "$2" ] && [ -f $2 ] && echo $2) || echo "reads.fa")

Enzyme=GCTCTTC

###
queue=all.q
InterIncluded_Side=25000

InterIncluded_Identity=99;
InterIncluded_Coverage=99;

MinIdentity=98
MinCoverage=90
MinLength=5000

MinIdentity_Overlap=97
MinOverlap_Overlap=1000
MaxOverhang_Overlap=100
MinExtend_Overlap=1000

MinPathNum=5

MinIdentity_Merge=98
MinOverlap_Merge=10000
MaxOverhang_Merge=200

Bionano_Scaffolded_Contig=Large_Contig.fasta
Bionano_NonScaffolded_Contig=Small_Contig.fasta

runCMD(){
	((count=$count+1))
	set -vex
	if [ -f "job$count.done" ];then
		return 0
	fi
	date +"# job_$count start %Y-%m-%d %H:%M:%S"
	echo $1 | bash
	touch "job$count.done"
	date +"# job_$count  end  %Y-%m-%d %H:%M:%S"
}

export PATH=$Working_Script:$DAZZ_DB:$DALIGNER:$BWA:$MINIMAP2:$PATH
mkdir -p log

mkdir -p 01-Pacbio_And_NonScaffold
cd 01-Pacbio_And_NonScaffold
$Working_Script/Check
cd -
mkdir -p 02-Pacbio-Alignment
cd 02-Pacbio-Alignment
$Working_Script/Check
cd -
mkdir -p 03-Pacbio-SelfAlignment
cd 03-Pacbio-SelfAlignment
$Working_Script/Check
cd -
mkdir -p 04-Graphing
cd 04-Graphing
$Working_Script/Check
cd -
mkdir -p 05-PathContig
cd 05-PathContig
$Working_Script/Check
cd -
mkdir -p 06-Daligner
cd 06-Daligner
$Working_Script/Check
cd -
mkdir -p 07-FilledGap
cd 07-FilledGap
$Working_Script/Check
cd -
mkdir -p 08-PathContig_Consensus
mkdir -p 09-ReAssembly
$Working_Script/Check

# job 1
runCMD "$Working_Script/readstoline $genome_seq $genome_name-Genome.fasta C"
# job 2
runCMD "$Working_Script/01-Filter_Raw_Contig_By_Length $genome_name-Genome.fasta Large_Contig.fasta Small_Contig.fasta 50000 15000"
# job 3
runCMD "$Working_Script/readstoline $Corrected_Pacbio $genome_name-CorrectedPacbio.fasta P"


Corrected_Pacbio=$genome_name-CorrectedPacbio.fasta

# job 4
runCMD "cat $Bionano_NonScaffolded_Contig $Corrected_Pacbio >Query_Merged.fasta"

cd ./01-Pacbio_And_NonScaffold

# job 5
runCMD "$Working_Script/03-fasta-splitter --n-parts 100 ../Query_Merged.fasta"

cd -
# job 6
runCMD "ls ./01-Pacbio_And_NonScaffold/*.fasta >list_Split.txt"

# job 7
runCMD "$MINIMAP2/minimap2 -d $Bionano_Scaffolded_Contig.mmi $Bionano_Scaffolded_Contig"

# job 8
runCMD "perl $Working_Script/04-Qsub-Mapping2Ctg_minimap2.pl list_Split.txt $Bionano_Scaffolded_Contig.mmi ./02-Pacbio-Alignment $Working_Script $queue $genome_name >log/all_log.txt"

sleep 20;
job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-Map | wc -l`;
while (($job>=1))
	do job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-Map | wc -l`;echo $job;sleep 20;
done

rm -f *.o*
rm -f [0-9]*.pbs

# job 9
runCMD "cat ./02-Pacbio-Alignment/Part_Alignment_*.txt > ./02-Pacbio-Alignment/Total_Alignment.txt"


# job 10
runCMD "$Working_Script/05-Filtered_InterIncluded_Pacbio ./02-Pacbio-Alignment/Total_Alignment.txt ./02-Pacbio-Alignment/InterIncluded_Pacbio.txt $InterIncluded_Identity $InterIncluded_Coverage $InterIncluded_Side"


# job 11
runCMD "$Working_Script/06-Extract_Contig_Head_Tail_Pacbio_Alignment -Align=./02-Pacbio-Alignment/Total_Alignment.txt -MinIden=$MinIdentity -MinCov=$MinCoverage -HTLen=$InterIncluded_Side -MinLen=$MinLength"

# job 12
runCMD "$Working_Script/10-Switch_Locus_To_Positive Contig_Head_Tail_Pacbio.txt ./04-Graphing/Contig_Head_Tail_Pacbio_Pos.txt"

# job 13
runCMD "$Working_Script/07-extract_fasta_seq_by_name ./02-Pacbio-Alignment/InterIncluded_Pacbio.txt ./Query_Merged.fasta ./02-Pacbio-Alignment/Both_Side_Pacbio.fasta"

cd ./03-Pacbio-SelfAlignment
# job 14
runCMD "$Working_Script/03-fasta-splitter --n-parts 30 ../02-Pacbio-Alignment/Both_Side_Pacbio.fasta"

cd -
# job 15
runCMD "ls ./03-Pacbio-SelfAlignment/*.fasta >list_outer_pacbio.txt"

# job 16
runCMD "perl $Working_Script/08-qsub_job_index_minimap2.pl list_outer_pacbio.txt $queue $genome_name>>log/all_log.txt"

sleep 20
job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-INDEX|wc -l`
while (($job>=1))
	do job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-INDEX|wc -l`;echo $job;sleep 20;
done

rm -f *.o*
rm -f [0-9]*.pbs
sleep 10;

# job 17
runCMD "perl $Working_Script/09-Qsub-Pair_Alignment_minimap2.pl list_outer_pacbio.txt $Working_Script $queue $genome_name >>log/all_log.txt"

sleep 20
job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-Pair | wc -l`
while (($job>=1))
	do job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-Pair | wc -l`;echo $job;sleep 20;
done

rm -f *.o*
rm -f [0-9]*.pbs

# job 18
runCMD "cat ./03-Pacbio-SelfAlignment/Part_SelfAlignment_*.txt > ./03-Pacbio-SelfAlignment/Total_SelfAlignment.txt"

# job 19
runCMD "$Working_Script/11-PacbioAlignmentFilter ./03-Pacbio-SelfAlignment/Total_SelfAlignment.txt $MaxOverhang_Overlap $MinIdentity_Overlap $MinOverlap_Overlap $MinExtend_Overlap > ./04-Graphing/PacbioAlignmentFiltered.txt"

# job 20
runCMD "$Working_Script/12-PacbioAlignmentLinker ./04-Graphing/PacbioAlignmentFiltered.txt $MaxOverhang_Overlap $MinExtend_Overlap > ./04-Graphing/PacbioAlignmentLinked.txt"


cd ./04-Graphing/

# job 21
runCMD "$Working_Script/Selected_Best_Pairs PacbioAlignmentLinked.txt PacbioAlignmentLinked_BestMatch.txt"
# job 22
runCMD "$Working_Script/13-Graph_By_Finding_Best_MaxExtending_Random_Path PacbioAlignmentLinked_BestMatch.txt >check"

# job 23
runCMD "cat ctg_clusters.txt |sort |uniq > ../05-PathContig/ctg_clusters_uniq.txt"
# job 24
runCMD "cat cluster_ori.txt |sort |uniq > ../05-PathContig/cluster_ori_uniq.txt"

cd -


cd 05-PathContig
# job 25
runCMD "$Working_Script/14-make_ctg_line cluster_ori_uniq.txt cluster_ori_same_chain.txt"

# job 26
runCMD "$Working_Script/18-compute_fasta_file_len ../Query_Merged.fasta Query_Len.txt"

# job 27
runCMD "$Working_Script/15-make_junction_by_pos ../04-Graphing/ctg_pairs.txt Query_Len.txt cluster_ori_same_chain.txt cluster_ori_same_chain_pos.txt"

# job 28
runCMD "$Working_Script/16-extract_ctg_infor_for_seq cluster_ori_same_chain_pos.txt cluster_ori_same_chain_pos_for_seq.txt"
# job 29
runCMD "echo '>NA' >NA.fasta; echo 'ATCG' >>NA.fasta ; $Working_Script/17-extract_seq_by_pos cluster_ori_same_chain_pos_for_seq.txt ../Query_Merged.fasta NA.fasta PathContig.fasta"

# job 30
runCMD "$Working_Script/18-compute_fasta_file_len PathContig.fasta ../06-Daligner/PathContig_Len.txt"

cd -


mkdir -p 10-Contig_Pairs
cd 10-Contig_Pairs
$Working_Script/Check
touch overlap.txt

# job 31
runCMD "$Working_Script/03-Formate_Contig_Pairs_By_Paths overlap.txt ../05-PathContig/ctg_clusters_uniq.txt Contig_Pairs.txt"

# job 32
runCMD "cat Contig_Pairs.txt |awk '{if((\$5+\$6/3+\$7/6)>='$MinPathNum'){\$8=\$5+\$6/3+\$7/6;print \$0;}}' >Contig_Pairs_Filtered.txt"

# job 33
runCMD "$Working_Script/05-Merge_With_HighestScore_To_Sequence_By_Path Contig_Pairs_Filtered.txt ../Large_Contig.fasta SuperContig.fasta >Selected_Pairs.txt"

cd -

cd 06-Daligner

# job 34
runCMD "$Working_Script/19-Path2Scaffold_NoBioNano ../10-Contig_Pairs/Selected_Pairs.txt ../05-PathContig/ctg_clusters_uniq.txt PathContig_Len.txt Path_Scaffold.txt"

# job 35
runCMD "$Working_Script/20-PathContig-Rename_NoBioNano Path_Scaffold.txt ../05-PathContig/PathContig.fasta PathContig_Rename.fasta > ../log/all_log.txt"

# job 36
runCMD "$Working_Script/Rename1 ../10-Contig_Pairs/SuperContig.fasta  SuperContig_Rename.fasta >Rename_Pairs.txt"
# job 37
runCMD "$Working_Script/Rename2 Rename_Pairs.txt PathContig_Rename.fasta PathContig_Rename2.fasta"
# job 38
runCMD "mv -f PathContig_Rename2.fasta PathContig_Rename.fasta"

# job 39
runCMD "$Working_Script/01-Gap_Count SuperContig_Rename.fasta $Enzyme Gap.txt"
# job 40
runCMD "$Working_Script/01-Finding_Contigs_Gap Gap.txt Scaffold2Ctg_Gap.txt"
# job 41
runCMD "$Working_Script/02-Split_Scaffold_To_Contigs SuperContig_Rename.fasta Prosudo_ScaffoldNonEnzyme2Contig.fasta $Enzyme"

# job 42
runCMD "perl $Working_Script/21-Daligner_New.pl Scaffold2Ctg_Gap.txt Prosudo_ScaffoldNonEnzyme2Contig.fasta PathContig_Rename.fasta $queue qsub $Working_Script $genome_name $DAZZ_DB $DALIGNER"

sleep 20;
job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-DALIGNER | wc -l`;
while (($job>=1))
	do job=`qstat -xml | perl -ne 'print "$1\n" if(m#<JB_name>(.*?)</JB_name>#)' | grep $genome_name-DALIGNER | wc -l`;echo $job;sleep 20;
done

rm -f *.o[0-9]*
rm -f [0-9]*.pbs

# job 43
runCMD "$Working_Script/22-Filling-Gap Scaffold2Ctg_Gap.txt Prosudo_ScaffoldNonEnzyme2Contig.fasta PathContig_Rename.fasta SuperContig.fasta"


# job 44
runCMD "cat SuperContig.fasta ../$Bionano_NonScaffolded_Contig |awk 'BEGIN{count=1;}{if(\$0~/^>/){print \">SuperContig\"count\"END\";count++;}else{print \$0;}}' >../$genome_name-Final_Genome_HERA.fasta"


#!/usr/bin/perl
#Author: huilong du
#Note: align the corrected pacbios and non-scaffolded contigs to scaffolded contigs
use warnings;
use strict;

my $infile=shift;
my $ref=shift;
my $output=shift;
my $script=shift;
my $queue=shift;
my $genome=shift;

open IN,"<$infile" or die $!;

my $count=1;

while(<IN>){
    chomp;
    my $line=$_;
    open OUT,">$count.pbs" or die $!;
    if($count<120){
        print OUT "#BSUB -J $genome-Map-$count
#BSUB -o $count.out
#BSUB -n 1
#BSUB -q $queue
";
     }
     elsif($count>=120){
        print OUT "#BSUB -J $genome-Map-$count
#BSUB -o $count.out
#BSUB -n 1
#BSUB -q $queue
";
     }
print OUT " 
minimap2 -a -t 4 $ref $line >$output/Part_Alignment_$count.sam
perl $script/sam2blasr.pl $output/Part_Alignment_$count.sam $output/Part_Alignment_$count.txt
rm -f $output/Part_Alignment_$count.sam
";
     close(OUT);
     system("qsub -cwd -V -e log/ -l vf=10g,p=1 -q $queue -o $count.out -N $genome-Map-$count  < $count.pbs");
     $count++;
}
close(IN);


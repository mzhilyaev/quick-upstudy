#!/usr/bin/perl

use strict;
use Data::Dumper;
use File::Basename;
use Getopt::Long;
use File::Path;
use File::Basename;

my $mysql = "/usr/local/mysql/bin/mysql";
my $help;
my $inFile = "reports.perl";
my $surveyFile = "survey.xml";
my $histFile = "history.json";
my $dbname = "upstudy1";
my $regen;

if(
     !GetOptions (
            "help|h" => \$help ,
            "input|i=s" => \$inFile ,
            "survey|s=s" => \$surveyFile ,
            "hist|h=s" => \$histFile ,
            "db|d=s" => \$dbname ,
            "regen|r" => \$regen ,
     )
     || defined( $help )  ### or help is wanted
     || !defined( $inFile )
     || (!defined($regen) && (!defined($surveyFile) || !defined($histFile)))
) {
        usage( );
}


sub usage {

   print "Usage $0 [OPTIONS]
   Generates scored categories
            --help|-h       - prints this help
            --input|-i      - input perl file
            --survey|-s     - input survey xml file
            --hist|-h       - input history file
            --db|-d         - dbname
            --regen|-r      - regen flag
            \n";
    exit 1;
}

### change directory to where script is
my $location = dirname( `/usr/bin/which $0` );
chdir $location;

if (!$regen) {
  # rtecreate database
  print "cat create_tables.sql edcats 58cats | $mysql -u admin $dbname\n";
  `cat create_tables.sql edcats 58cats | $mysql -u admin $dbname`;
  print "./procHistory.pl -i $histFile -d | $mysql -u admin $dbname\n";
  `./procHistory.pl -i $histFile -d | $mysql -u admin $dbname`;
  print "./procSurvey.pl -i $surveyFile -d | $mysql -u admin $dbname\n";
  `./procSurvey.pl -i $surveyFile -d | $mysql -u admin $dbname`;
  print "cat postpopulate.sql | $mysql -u admin $dbname\n";
  `cat postpopulate.sql | $mysql -u admin $dbname`;
}

my $data = "";
open(FILE,"< $inFile");
while(<FILE>) {
  $data .= $_;
}
close(FILE);

my $perl_scalar = (eval $data);
die "$@ unable to parse $inFile" if ($@);


#print Dumper($perl_scalar);

my $outdir = $perl_scalar->{_CONF}->{outdir};
`rm -rf $outdir`;
mkdir $outdir;

my $qindex = 1;

open(INDEX,"> $outdir/index.html");
for my $key (keys %$perl_scalar) {
  next if($key =~ /^_/);

  print INDEX "<h3>$key</h3>\n";
  for my $query (@{$perl_scalar->{$key}}) {
    my $qfile = "query_$qindex.html";
    print INDEX "  <li><a href='$qfile'/>$query->{title}</a></li>\n";
    outputFile($qfile, $query->{title}, $query->{query});
    $qindex++;
  }
}
close(INDEX);

sub outputFile {
  my ($file, $title, $query) = @_;
  my $tmp = "$outdir/$$.tmp";
  $file = "$outdir/$file";

  open(OUTPUT, "> $tmp");
  print OUTPUT $query."\nQUIT\n";
  close(OUTPUT);

  open(OUTPUT, "> $file");
  print OUTPUT "<h3>$title</h3>\n";
  print OUTPUT "<pre>\n";
  close(OUTPUT);

  `cat $tmp | $mysql -t -u admin $dbname >> $file`;
  `rm $tmp`;
}

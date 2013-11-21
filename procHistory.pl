#!/usr/bin/perl

use strict;
use Data::Dumper;
use JSON;
use List::Util qw(sum);
use Getopt::Long;

my $help;
my $inFile;
my $dbfy;

if(
     !GetOptions (
            "help|h" => \$help ,
            "input|i=s" => \$inFile ,
            "dbfy|d" => \$dbfy ,
     )
     || defined( $help )  ### or help is wanted
     || !defined( $inFile )
) {
        usage( );
}


sub usage {

   print "Usage $0 [OPTIONS]
   Generates scored categories
            --help|-h       - prints this help
            --input|-i      - input json file
            --dbfy|-d      - generate database dump
            \n";
    exit 1;
}

my $json = JSON->new();

my $algs = {};
my $data = "";
open(FILE,"< $inFile");
while(<FILE>) {
  procData($_);
}
close(FILE);

if (!$dbfy) {
  print Dumper($algs);
}
else {
  output();
}


sub addDays {
    my ($sink,$cat,$hostsVisist) = @_;
    $sink += 1;
}

sub computeScores {
    my ($uuid,$day,$type,$ns,$cat,$hostsVisist) = @_;
    # make a key
    my $key = "$type.$ns.$cat";  
    $algs->{$uuid}->{counts}->{"daycount.$key"} ++;
    $algs->{$uuid}->{counts}->{"hostcount.$key"} += scalar(@$hostsVisist);
    $algs->{$uuid}->{counts}->{"visitcount.$key"} += sum(@$hostsVisist);
}

# compute scroes for each category
sub procData {
  my $data = shift;
  my $perl_scalar = $json->decode( $data );
  #print Dumper($perl_scalar);
  my $uuid = $perl_scalar->{"uuid"};
  if(!$algs->{$uuid}) {
    $algs->{$uuid}->{day} = 0;
    $algs->{$uuid}->{days} = {};
    $algs->{$uuid}->{daycount} = 0;
    $algs->{$uuid}->{counts} = {};
  }

  for my $day (keys %{$perl_scalar->{interests}}) {
    if (!$algs->{$uuid}->{days}->{$day}) {
      $algs->{$uuid}->{daycount} ++;
      $algs->{$uuid}->{days}->{$day} = 1;
      if ($algs->{$uuid}->{day} < $day) {
        $algs->{$uuid}->{day} = $day;
      }
      for my $type (keys %{$perl_scalar->{interests}->{$day}}) {
          for my $ns (keys %{$perl_scalar->{interests}->{$day}->{$type}}) {
              for my $cat (keys %{$perl_scalar->{interests}->{$day}->{$type}->{$ns}}) {
                  computeScores($uuid,$day,$type,$ns,$cat,$perl_scalar->{interests}->{$day}->{$type}->{$ns}->{$cat});
              }
          }
      }
    }
  }
}

sub output {
  #print Dumper($algs);
  for my $uuid (keys %$algs) {
    my $userAlgs = $algs->{$uuid}->{counts};
    my @sorted = sort {
       my $x = $a;
       my $y = $b;

       $x =~ s/\.[\w-]+$//;
       $y =~ s/\.[\w-]+$//;

       if ($x eq $y) {
        return $userAlgs->{$b} - $userAlgs->{$a};
       }
       else {
        return $y cmp $x;
       }
    }  keys %$userAlgs;

    print "insert ignore into UUID value(NULL, '$uuid');\n";
    print "insert into Payloads value('$uuid',$algs->{$uuid}->{daycount}, $algs->{$uuid}->{day});\n";
    print "delete from ScriptData;\n";
    my $lastSet = "";
    my $rank = 1;
    for my $key (@sorted) {
        my $name = $key;
        $name =~ s/\.[\w-]+$//;
        if ($name ne $lastSet) {
           #close(FILE);
           #open(FILE, "> $name.out");
           $lastSet = $name;
           $rank = 1;
           print "insert ignore into Algs value(NULL, '$lastSet');\n";
        }
        my $score = $userAlgs->{$key};
        $key =~ s/^.*\.//;
        print "insert into ScriptData value('$uuid', '$lastSet', '$key', $score, $rank);\n";
        $rank++;
    }
    print "replace into AlgRanks select uid , aid , cid , score , rank from ScriptData, UUID, Algs, Cats where uuid = UUID.name and alg = Algs.name and cat = Cats.name;\n";
  }
  print "insert into HistSize select uid , days from UUID , Payloads where UUID.name = Payloads.uuid;\n";
}

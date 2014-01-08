#!/usr/bin/perl

use strict;
use Data::Dumper;
use JSON;
use List::Util qw(sum);
use Getopt::Long;

my $help;
my $inFile;
my $dbfy;
my $mapf;
my $keepf;

if(
     !GetOptions (
            "help|h" => \$help ,
            "input|i=s" => \$inFile ,
            "map|m=s" => \$mapf ,
            "dbfy|d" => \$dbfy ,
            "keep|k=s" => \$keepf ,
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
            --map|-m      - intertest to namespace map
            --keep|-k      - keyword cats
            \n";
    exit 1;
}

my $map = {};
open(FILE, "<$mapf");
while(<FILE>) {
  chomp($_);
  my($interest, $namespace) = split(/ /,$_);
  $map->{$interest} = $namespace;
}
close(FILE);

my $kwKeep = {};
open(FILE, "<$keepf");
while(<FILE>) {
  chomp($_);
  $kwKeep->{$_} = 1;
}
close(FILE);


my $json = JSON->new();

my $algs = {};
my $data = "";
my $ind = 1;
open(FILE,"< $inFile");
while(<FILE>) {
  procData($_);
  #print "$ind\n";
  $ind++;
}
close(FILE);

if (!$dbfy) {
  print Dumper($algs);
}
else {
  synth();
  output();
}


sub synth {
  for my $uuid (keys %$algs) {
    my $userAlgs = $algs->{$uuid}->{counts};
    for my $key (keys %$userAlgs) {
      my ($method,$type,$ns,$cat) = split(/\./ , $key);
        if( $type eq "combined" && $ns =~ /edrules/ && $method ne "visitcount") {
          my $new_key = "$method.partial_combined.$ns.$cat";
          if ($kwKeep->{$cat}) {
            $userAlgs->{$new_key} = $userAlgs->{$key};
          }
          else {
            my $ruleKey = "$method.rules.$ns.$cat";
            if (exists $userAlgs->{$ruleKey}) {
              $userAlgs->{$new_key} = $userAlgs->{$ruleKey};
            }
          }
        }
    }
  }

  for my $uuid (keys %$algs) {
    my $userAlgs = $algs->{$uuid}->{counts};
    for my $key (keys %$userAlgs) {
      my ($method,$type,$ns,$cat) = split(/\./ , $key);
        if( $ns eq "edrules" || $ns eq "edrules_extended") {
           my $map_ns = $map->{$cat} || "edrules";
           if ($map_ns eq $ns) {
             my $new_key = "$method.$type.rules_synthetic.$cat";
             $userAlgs->{$new_key} = $userAlgs->{$key};
           }
        }
    }
 }
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
    $algs->{$uuid}->{counts}->{"sqrt_hcnt.$key"} += sqrt(scalar(@$hostsVisist));
    $algs->{$uuid}->{counts}->{"visitcount.$key"} += sum(@$hostsVisist);

    #sumweight[android] = 1;
    #visitweight[android] = 0;
    #$algs->{$uuid}->{counts}->{"smartcount.$key"} += sum(@$hostsVisist) * sumweight[cat] + scalar(hostvisits) * visitweight[cat];
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
  `rm -f /tmp/theoutfile`;
  open( FILE ," > /tmp/theoutfile");
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
        #print "insert into ScriptData value('$uuid', '$lastSet', '$key', $score, $rank);\n";
        print FILE "$uuid\t$lastSet\t$key\t$score\t$rank\n";
        $rank++;
    }
  }
  close(FILE);
  print "delete from ScriptData;\n";
  print "load data infile '/tmp/theoutfile' into table ScriptData;\n";
  print "replace into AlgRanks select uid , aid , cid , score , rank from ScriptData, UUID, Algs, Cats where uuid = UUID.name and alg = Algs.name and cat = Cats.name;\n";
  print "insert ignore into HistSize select UUID.uid , days , country , sum( AlgRanks.score) score_sum
                from UUID , Payloads , Surveys , Algs , AlgRanks 
                where UUID.name = Payloads.uuid 
                    and Surveys.uuid = UUID.name 
                    and AlgRanks.uid = UUID.uid
                    and Algs.aid = AlgRanks.aid
                    and Algs.name = 'daycount.rules.edrules_extended'
                group by UUID.uid;"
}

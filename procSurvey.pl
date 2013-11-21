#!/usr/bin/perl

use strict;
use Data::Dumper;
use JSON;
use Getopt::Long;
use XML::Simple;

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
            --input|-i      - input csv file
            --dbfy|-d      - produce database dump
            \n";
    exit 1;
}


my $json = JSON->new();
my $data = "";
open(FILE,"< $inFile");
while(<FILE>) {
  $data .= $_;
}
close(FILE);

my $ref = XMLin($data);
my $rows = $ref->{Worksheet}->{Table}->{Row};

my $rrow = shift @$rows;
my $frow = $rrow->{Cell};

sub findHeader {
  my $header = shift;
  my $i = 0;
  while ($i < scalar(@$frow)) {
    if($frow->[$i]->{Data}->{content} eq $header) {
      return $i;
    }
    $i++;
  }
  return $i;
}

sub extractInterests {
  my $dict = shift;
  my $cats = [];
  my $interests = $json->decode( $dict->{interests});
  my @scoreList = split(/,/,$dict->{scoreList});
  while(my ($url,$val) = each %$dict) {
    my $key = $url;
    $key =~ s/^.url."//;
    $key =~ s/".*$//;
    my $position = $key;
    $position =~ s/^interest//;
    my $surveyScore = 0 + $scoreList[$position-1];

    if ($url =~ /top_5/) {
      if ($val) {
        push @$cats , [$interests->{$key},1,1,$surveyScore];
      }
      else {
        push @$cats , [$interests->{$key},0,1,$surveyScore];
      }
    }
    elsif ($url =~ /additional_interests/) {
      push @$cats , [$interests->{$key},2,0,$surveyScore];
    }
    elsif($interests->{$key}) {
      push @$cats , [$interests->{$key},0,0,$surveyScore];
    }
  }
  return ($cats);
}

sub genDB {
 my $dict = shift;
 my $cats = extractInterests($dict);
 my $uuid = $dict->{userID};
 my $respid = $dict->{"Response ID"};
 my $country = $dict->{"Country"};
 my $lang = $dict->{"Language"};
 my $submitted = $dict->{"Date Submitted"};
 my $users = (0  + $dict->{"computer_users"}) || "NULL";
 if ($uuid) {
   print "insert ignore into Surveys value('$uuid',$respid,'$country','$lang','$submitted','$users');\n";
   print "insert ignore into UUID value(NULL, '$uuid');\n";
   print "delete from SurveyData;\n";
   for my $item (@$cats) {
    my $cat = $item->[0];
    my $choice = $item->[1];
    my $top5 = $item->[2];
    my $surveyScore = $item->[2];
    print "insert ignore into SurveyData value('$uuid','$cat',$choice,$top5,$surveyScore);\n";
   }
   print "replace into UserChoice select uid , cid , choice, isTop5, surveyScore from SurveyData, UUID, Cats where uuid = UUID.name and cat = Cats.name;\n";
 }
}

for my $rrow (@$rows) {
  my $dict = {};
  my $row = $rrow->{Cell};
  my $i = 0;
  #print scalar(@$row) . " " . scalar(@$frow) , " =====\n";
  die "DIFERENT LEN\n" if( scalar(@$row) != scalar(@$frow));
  while( $i < scalar(@$row)) {
    if ($row->[$i]->{Data}->{content} || $frow->[$i]->{Data}->{content} =~ /:top_5/) {
      $dict->{$frow->[$i]->{Data}->{content}} = $row->[$i]->{Data}->{content};
    }
    $i++;
  }

  if (!$dict->{userID}) {
    next;
  }

  ### unpack interests
  #my $perl_scalar = $json->decode( $data );
  if ($dbfy) {
    genDB($dict);
  }
  else {
    print "\n";
    for my $key (sort { findHeader($a) <=> findHeader($b) } keys %$dict) {
      print "$key = ".$dict->{$key}."\n";
    }
    my $cats = extractInterests($dict);
    my $tops = "";
    my $adds = "";
    my $rest = "";
    #print Dumper($cats);
    map { 
      if($_->[1] == 1) { $tops.=" ".$_->[0];}
      if($_->[1] == 2) { $adds.=" ".$_->[0];}
      if(!$_->[1]) { $rest.=" ".$_->[0];}
    } @$cats;
    print "TOP: $tops\n";
    print "ADDITIONAL: $adds\n";
    print "REST: $rest\n";
  }
}


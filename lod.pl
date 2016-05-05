#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my $objName      = "";

&GetOptions("objname=s"       => \$objName,
);

if ($objName eq "stoneware.bin" ) { write_size  ($objName);}

sub wr_bin {
  my ($word) = @_;
  my @byte = ();
  $byte[0] = $word & 0xff;
  $byte[1] = ($word >> 8) & 0xff;
  $byte[2] = ($word >> 16) & 0xff;
  $byte[3] = ($word >> 24) & 0xff;
  printf ("%c%c%c%c", $byte[0], $byte[1], $byte[2], $byte[3]);
}

sub write_size {
  my ($objname, $addr) = @_;

  open (P, "<$objname") or die ("Could not open $objname for reading");
  binmode (P); 
  binmode (STDOUT);
  my @file = ();
  my $cnt=0;
  my $byte;
  while (read (P, $byte, 1) == 1) { 
    $cnt++;
    push @file, $byte;

  }

  wr_bin($cnt); 
  print @file;

}

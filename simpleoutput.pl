#!/usr/bin/perl -w
use strict;
use XML::Simple;
use Data::Dumper;
my $simple = XML::Simple->new(ForceArray=>1, KeepRoot=>1);
#my $data   = $simple->XMLin('blog-small.xml');
my $data   = $simple->XMLin('perl-xml-quickstart/files/camelids.xml');

# DEBUG
print Dumper($data) . "\n";

#print "$data->{name} is $data->{age} years old and works in the $data->{department} section\n";
# END

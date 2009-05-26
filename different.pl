#!/usr/bin/perl -w

use strict;

use XML::Parser;
use XML::SimpleObject;

my $file = 'perl-xml-quickstart/files/camelids.xml';

my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");
my $xso = XML::SimpleObject->new( $parser->parsefile($file) );

foreach my $species ($xso->child('camelids')->children('species')) {
    print $species->child('common-name')->value; 
    print ' (' . $species->attribute('name') . ') ';
    print $species->child('conservation')->attribute('status');
	print $species->child('physical-characteristics')->child('appearance')->value;
    print "\n";
}

#!/usr/bin/perl -w
use strict;
binmode(STDOUT, ":utf8");
#open(OUTPUT, ">:encoding(utf8)", "output.txt");

use XML::Parser;
use XML::SimpleObject;

#my $file = 'blog-small.xml';
#my $file = 'blog-huge.xml';
my $file = 'jordan.xml';

my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");
my $xso = XML::SimpleObject->new( $parser->parsefile($file) );

foreach my $posts (reverse($xso->child('feed')->children('entry'))) {
#foreach my $posts ($xso->child('feed')->children('entry')) {
	# Use a dispatch table for post and comment functions?
	if ($posts->child('category')->attribute('term') =~ /post/) {
		print $posts->child('title')->value;	
		print " - ";	
		print $posts->child('author')->child('name')->value;
		print " (" . $posts->child('published')->value . ")\n";
		print $posts->child('content')->value;
	    print "\n\n\n";
		# Strip HTML - s/<(?:[^>'"]*|(['"]).*?\1)*>//gs
	} 
}

#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;

binmode(STDOUT, ':utf8');
#open(OUTPUT, ">:encoding(utf8)", "output.txt");

my $file = 'blog-small.xml';
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);
my $xc = XML::LibXML::XPathContext->new( $doc->documentElement() );
$xc->registerNs( post => 'http://www.w3.org/2005/Atom' );

foreach my $entry (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category/@term', $entry);
	if ($type =~ /post/) {
		my $title = ($xc->findvalue('./post:title', $entry) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $entry);
		my $content = ($xc->findvalue('./post:content', $entry) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $entry);
		my $author = $xc->findvalue('./post:author/post:name', $entry);
		my $date = $xc->findvalue('./post:published', $entry);
		my $comments = $xc->findvalue('./post:link[2]/@title', $entry);
		
		print "$title\n$author - $date\n$comments\n$content\n\n";
	}
}


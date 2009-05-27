#!/usr/bin/perl -w

use strict;
use warnings;

use Date::Format; #http://search.cpan.org/dist/TimeDate/lib/Date/Format.pm
use Date::Parse;
use XML::LibXML;
use XML::LibXML::XPathContext;

binmode(STDOUT, ':utf8');
#open(OUTPUT, ">:encoding(utf8)", "output.txt");

my $file = 'files/blog-small.xml';
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);
my $xc = XML::LibXML::XPathContext->new($doc->documentElement());
$xc->registerNs(post => 'http://www.w3.org/2005/Atom');

# Start InDesign tagged text
print "<ASCII-MAC>\n";

# Reverse and loop through all the entries in the XML file
foreach my $entry (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category/@term', $entry);
	if ($type =~ /post/) {
		my $title = ($xc->findvalue('./post:title', $entry) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $entry);
		my $content = ($xc->findvalue('./post:content', $entry) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $entry);
		my $author = $xc->findvalue('./post:author/post:name', $entry);
		my $date = $xc->findvalue('./post:published', $entry);
		my $comments = $xc->findvalue('./post:link[2]/@title', $entry);
		
		print "<ParaStyle:Post Title>$title\n";
		
		# Get and format the date - FIXME: Get the time zone right
		$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g;
		$date = time2str("%A, %B %e, %Y - %l:%M %p", str2time($date), "0");				
		
		print "<ParaStyle:Post Date>$date\n";
		print "<ParaStyle:Post Author>$author\n";
		
		# Replace <br />s with newlines and appropriate tags
		# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
		$content =~ s/<br \/><br \/>/\n<ParaStyle:Main text>/gi;
		$content =~ s/<br \/>/\n<ParaStyle:Main text>/gi;
		
		# Find href="" in all links and linked text - strip out the rest of the HTML - TODO: These could/should be combined into one someday
		$content =~ s/<a\s[^>]*href=\"([^\"]*)\"[^>]*>(.*?)<\/a>/### $2 ($1) ###/gs; # Double quotes (href=""")
		$content =~ s/<a\s[^>]*href=\'([^\']*)\'[^>]*>(.*?)<\/a>/### $2 ($1) ###/gs; # Single quotes (href='')
		
		# Remove any extra spaces
		$content =~ s/[ ]{2,10}/ /gsi;
		
		# Print the final content variable, preceded with ID First paragraph style
		print "<ParaStyle:First paragraph>$content\n\n";
		
		#$content =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs; # Kill all tags violently
	}
}


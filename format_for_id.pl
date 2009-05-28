#!/usr/bin/perl -w
# FIXME: Why do I keep getting this error: Can't find string terminator '"' anywhere before EOF at -e line 1.
use strict;
use warnings;
use diagnostics;

##################
# Initial set up
##################
# Dependent packages
use Date::Format; #http://search.cpan.org/dist/TimeDate/lib/Date/Format.pm
use Date::Parse;
use XML::LibXML;
use XML::LibXML::XPathContext;

# Open output file, set encoding to unicode
#binmode(STDOUT, ':utf8');
open(OUTPUT, ">:encoding(utf8)", "output.txt");

# Connect to file and start parsing it
my $file = 'files/blog-huge.xml';
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);
my $xc = XML::LibXML::XPathContext->new($doc->documentElement());
$xc->registerNs(post => 'http://www.w3.org/2005/Atom');

#####################
# Cleanup functions
#####################

#############################################################################
#
#	Function name: cleanDate
#	Purpose: Transform the date provided by Blogger into a string that can be used by Date::Parse's str2ime()
#	Incoming parameters: Blogger's date - 2008-02-29T08:50:00.000-08:00
#	Returns: Cleaned up date
#	Dependencies: Date::Format, Date::Parse
#	FIXME: Get the time zone right
#
#############################################################################

sub cleanDate($) {
	my $date= $_[0];
	$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g;
	$date = time2str("%A, %B %e, %Y - %l:%M %p", str2time($date), "0");
	return $date;
}


#############################################################################
#
#	Function name: cleanText
#	Purpose: Take out html tags, remove spaces, and generally clean up a string
#	Incoming parameters: Text
#	Returns: Cleaned up text
#	Dependencies: None
#
#############################################################################

sub cleanText($) {
	my $text = $_[0];
	
	# Replace <br />s with newlines and appropriate tags
	# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
	# TODO: Work with <p>s too
	# TODO: Make paragraph tags based on whether it is text or a comment - extra variable to the funtion?
	$text =~ s/<br \/><br \/>/\n<ParaStyle:Main text>/gi; # TODO: Allow for <BR> and <BR/>
	$text =~ s/<br \/>/\n<ParaStyle:Main text>/gi; # TODO: Combine with the first one?
	
	# Find href="" in all links and linked text - strip out the rest of the HTML 
	$text =~ s/<a\s[^>]*href=["']+?([^["']*)["']+?[^>]*>(.*?)<\/a>/### $2 ($1) ###/gs; # Both quotes (href="" & href='')
	
	# TODO: Work with <img> stuff
	
	# TODO: Work with spans for bold, italic, superscript, etc.
	
	# TODO: Clear out all other tags
	
	# Remove any extra spaces FIXME: Clear up final settings, like gsi - when are those really necessary? 
	$text =~ s/[ ]{2,10}/ /gsi;
	
	#$content =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs; # Kill all tags violently
	
	return $text;
}



##########################################################
# Parse the xml for all comments and save them in a hash
##########################################################

my %comments;
foreach my $comment (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category/@term', $comment);
	if ($type =~ /comment/) {
		my $content = ($xc->findvalue('./post:content', $comment) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $comment);
		my $author = $xc->findvalue('./post:author/post:name', $comment);
		my $date = $xc->findvalue('./post:published', $comment);
		$date = cleanDate($date);
		my $posturl = $xc->findvalue('./*[name()="thr:in-reply-to"]/@href', $comment);
		my $fullComment = "$date~~~$author~~~$content";
		$fullComment = cleanText($fullComment);
		
		# Store it all in the hash
		push @{$comments{$posturl}}, $fullComment;
	}
}


####################################
# Clean up and organize blog posts
####################################

# Start InDesign tagged text
my $output = "<ASCII-MAC>\n";

# Reverse and loop through all the blog entries in the XML file
foreach my $entry (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category[1]/@term', $entry);
	if ($type =~ /post/) {
		my $title = ($xc->findvalue('./post:title', $entry) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $entry);
		my $content = ($xc->findvalue('./post:content', $entry) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $entry);
		my $author = $xc->findvalue('./post:author/post:name', $entry);
		my $date = $xc->findvalue('./post:published', $entry);
		$date = cleanDate($date);
		my $commentsNum = $xc->findvalue('./post:link[2]/@title', $entry);
		my $posturl = $xc->findvalue('./post:link[5]/@href', $entry);
		# TODO: Get categories
		
		$output .= "\n\n<ParaStyle:Post Title>$title\n";
		$output .= "$posturl\n";			
		$output .= "<ParaStyle:Post Date>$date\n";
		$output .= "<ParaStyle:Post Author>$author\n";
		
		$content = cleanText($content);
		
		# Print the final content variable, preceded with ID First paragraph style
		$output .= "<ParaStyle:First paragraph>$content\n";
		
		
		############################
		# Add comments to the post
		############################
		 
		my $comments = '';
		
		foreach my $c (@{$comments{$posturl}}) {
			my @process_comment = split(/~~~/, $c);
			my $commentDate = $process_comment[0];
			my $commentAuthor = $process_comment[1];
			my $commentBody = $process_comment[2];
			$comments.= "$commentAuthor | $commentDate | $commentBody\n";
		}
		
		# If there are comments print them out
		if ($comments ne '') {
			$output .= "\nComments:\n";
			$output .= $comments;
			$output .= "\n";
		}
	}
}

print OUTPUT $output;
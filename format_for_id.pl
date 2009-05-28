#!/usr/bin/perl -w
# FIXME: Why do I keep getting this error: Can't find string terminator '"' anywhere before EOF at -e line 1.
use strict;
use warnings;

use File::Temp;
use Date::Format; #http://search.cpan.org/dist/TimeDate/lib/Date/Format.pm
use Date::Parse;
use XML::LibXML;
use XML::LibXML::XPathContext;

binmode(STDOUT, ':utf8');
open(OUTPUT, ">:encoding(utf8)", "output.txt");

my $file = 'files/jordan.xml';
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);
my $xc = XML::LibXML::XPathContext->new($doc->documentElement());
$xc->registerNs(post => 'http://www.w3.org/2005/Atom');


######################################
# Store comments in a temporary file 
######################################

# Open temporary file handle
my $tmpComments = File::Temp->new(SUFFIX=>'.txt') or die "File::Temp: $!\n";
binmode $tmpComments, ":utf8";

# Loop through all the comments and save them in $tmpComments
foreach my $comment (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category/@term', $comment);
	if ($type =~ /comment/) {
		my $content = ($xc->findvalue('./post:content', $comment) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $comment);
		my $author = $xc->findvalue('./post:author/post:name', $comment);
		my $date = $xc->findvalue('./post:published', $comment);
		my $posturl = $xc->findvalue('./*[name()="thr:in-reply-to"]/@href', $comment);
		
		# Get and format the date - FIXME: Get the time zone right 
		# TODO: Put the date stuff in a function
		$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g;
		$date = time2str("%A, %B %e, %Y - %l:%M %p", str2time($date), "0");
		
		print $tmpComments "$posturl~~~$date~~~$author~~~$content\n";
	}
}


####################################
# Clean up and organize blog posts
####################################

# Start InDesign tagged text
print OUTPUT "<ASCII-MAC>\n";

# Reverse and loop through all the blog entries in the XML file
foreach my $entry (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category/@term', $entry);
	if ($type =~ /post/) {
		my $title = ($xc->findvalue('./post:title', $entry) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $entry);
		my $content = ($xc->findvalue('./post:content', $entry) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $entry);
		my $author = $xc->findvalue('./post:author/post:name', $entry);
		my $date = $xc->findvalue('./post:published', $entry);
		my $commentsNum = $xc->findvalue('./post:link[2]/@title', $entry);
		my $posturl = $xc->findvalue('./post:link[5]/@href', $entry);
		
		print OUTPUT "\n\n<ParaStyle:Post Title>$title\n";
		print OUTPUT "$posturl\n";
		# Get and format the date - FIXME: Get the time zone right
		$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g;
		$date = time2str("%A, %B %e, %Y - %l:%M %p", str2time($date), "0");				
		
		print OUTPUT "<ParaStyle:Post Date>$date\n";
		print OUTPUT "<ParaStyle:Post Author>$author\n";
		
		# Replace <br />s with newlines and appropriate tags
		# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
		# TODO: Work with <p>s too
		# TODO: Put all this cleaning stuff in a function?
		$content =~ s/<br \/><br \/>/\n<ParaStyle:Main text>/gi; # TODO: Allow for <BR> and <BR/>
		$content =~ s/<br \/>/\n<ParaStyle:Main text>/gi; # TODO: Combine with the first one?
		
		# Find href="" in all links and linked text - strip out the rest of the HTML 
		$content =~ s/<a\s[^>]*href=["']+?([^["']*)["']+?[^>]*>(.*?)<\/a>/### $2 ($1) ###/gs; # Both quotes (href="" & href='')
		
		# TODO: Work with <img> stuff
		
		# TODO: Work with spans for bold, italic, superscript, etc.
		
		# TODO: Clear out all other tags
		
		# Remove any extra spaces FIXME: Clear up final settings, like gsi - when are those really necessary? 
		$content =~ s/[ ]{2,10}/ /gsi;
		
		# Print the final content variable, preceded with ID First paragraph style
		print OUTPUT "<ParaStyle:First paragraph>$content\n";
		
		
		################
		# Add comments
		################
		
		seek $tmpComments, 0, 0 or die "Seek $tmpComments failed: $!\n"; #Rewind temporary comments file
		my $comments = ''; # Initialize $comments
		
		# Loop through temporary file and find comments that match the post url
		while (my $line = <$tmpComments>) {
			# Split each line, store url as $commentID
			my @process_comment = split(/~~~/, $line);
			my $commentID = $process_comment[0];

			# If the urls match, add it to the comments variable
			if ($commentID eq $posturl) {
				my $commentDate = $process_comment[1];
				my $commentAuthor = $process_comment[2];
				my $commentBody = $process_comment[3];
				$comments.= "$commentDate | $commentAuthor | $commentBody";
			}
		}
		
		# If there are comments print them out
		if ($comments ne '') {
			print OUTPUT "\nComments:\n";
			print OUTPUT $comments;
		}
		
		#$content =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs; # Kill all tags violently
	}
}


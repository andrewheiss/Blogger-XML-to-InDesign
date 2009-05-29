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

# Open output file, set encoding to unicode - InDesign needs UTF16 Little Endian
binmode(STDOUT, ':utf8');

# Connect to file and start parsing it
my $file = 'files/blog-tiny.xml';
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);
my $xc = XML::LibXML::XPathContext->new($doc->documentElement());
$xc->registerNs(post => 'http://www.w3.org/2005/Atom');


my $setyear = "2009";

# InDesign tags - All these styles must be present in the InDesign file
my $IDstart = "<UNICODE-MAC>\n";
my $IDtitle = "<ParaStyle:Post Title>";
my $IDurl = "<ParaStyle:Post URL>";			
my $IDdate = "<ParaStyle:Post Date>";
my $IDauthor = "<ParaStyle:Post Author>";
my $IDparagraph = "<IDParaStyle:Main text>";
my $IDfirst = "<ParaStyle:First paragraph>";
my $IDcommentpara = "<ParaStyle:Comments\\:Comment text>";
my $IDcommentauthor = "<ParaStyle:Comments\\:Comment author>";
my $IDcommentdate = "<ParaStyle:Comments\\:Comment date>";
my $IDfootstart = "<IDcPosition:Superscript><IDFootnoteStart:>";
my $IDfootend = "<IDFootnoteEnd:><IDcPosition:>";
my $IDcharend = "<IDCharStyle:>";
my $IDitalic = "<IDCharStyle:Italic>";
my $IDbold = "<IDCharStyle:Bold>";
my $IDsmall = "<IDCharStyle:Small>";
my $IDsmallitalic = "<IDCharStyle:Small italic>";


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
	$date =~ s/[ ]{2,10}/ /gis;
	return $date;
}

sub getYear($) {
	my $date= $_[0];
	$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g;
	$date = time2str("%Y", str2time($date), "0");
	return $date;
}


#############################################################################
#
#	Function name: cleanText
#	Purpose: Take out html tags, remove spaces, and generally clean up a string
#	Incoming parameters: Text to be cleaned as $text, optional $type - use 'comment' to put appropriate styles in comments
#	Returns: Cleaned up text
#	Dependencies: None
#
#############################################################################

# TODO: Separate this into tag cleaning, line and space removing functions - maybe that'll fix it

sub cleanText {
	my $text = $_[0];
	my $type = defined $_[1] ? $_[1] : 'post'; # Makes the default text type 'post'
	
	my $IDcleanpara = ($type eq 'comment') ? $IDcommentpara : $IDparagraph ;
	
	# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
	# TODO: Make paragraph tags based on whether it is text or a comment - extra variable to the function?
	# Find any sequence of <br>s and replace with a new line
	$text =~ s/(<br\s?[\/]?>)+/\n$IDcleanpara/gis;
	$text =~ s/<p[^>]*>(.*?)<\/p>/\n$IDcleanpara$1/gis;
	
	# Find href="" in all links and linked text - strip out the rest of the HTML 
	$text =~ s/<a\s[^>]*href=["']+?([^["']*)["']+?[^>]*>(.*?)<\/a>/$2$IDfootstart$1$IDfootend/gis; # Both quotes (href="" & href='')
	
	# Find images, keep src link, strip the rest out
	$text =~ s/<img\s[^>]*src=["']+?([^["']*)["']+?[^>]*>/{$1}/gis;
	
	# Make any span with font-size in it smaller. It's not all really small, and there are different levels blogger uses. 78% seems to be the most common
	# TODO: Make me more flexible - find all the different current and historical blogger sizes
	$text =~ s/<span[^>]*?font-size[^>]*>(.*?)<\/span>/$IDsmall$1$IDcharend/gis;
	
	# TODO: Work with spans for bold, italic, superscript, etc.
	# Italicize text between <i>, <em>, and any span with the word italic in any attribute
	$text =~ s/<span[^>]*?italic[^>]*>(.*?)<\/span>/$IDitalic$1$IDcharend/gis;
	$text =~ s/<i>(.*?)<\/i>/$IDitalic$1$IDcharend/gis; 
	$text =~ s/<em>(.*?)<\/em>/$IDitalic$1$IDcharend/gis;
	
	# Bold text between <b>, <strong>, and any span with the word bold in any attribute
	$text =~ s/<span[^>]*?bold[^>]*>(.*?)<\/span>/$IDbold$1$IDcharend/gis;
	$text =~ s/<b>(.*?)<\/b>/$IDbold$1$IDcharend/gis; 
	$text =~ s/<strong>(.*?)<\/strong>/$IDbold$1$IDcharend/gis;
	
	#FIXME: ID can't handle nested character styles - combine them when necessary
	# $text =~ s/\Q$IDsmall\Q$IDitalic/$IDsmallitalic/gi;
	# $text =~ s/\Q$IDcharend\Q$IDcharend/$IDcharend/gi;
	# $text =~ s/<CharStyle:Small><CharStyle:Italic>/$IDsmallitalic/gi;
	# $text =~ s/<CharStyle:><CharStyle:>/$IDcharend/gi;
	
	$text =~ s/<span[^>]*>(.*?)<\/span>/$1/gis;
	
	# TODO: Clear out all other tags
	#$text =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs; # Kill all tags violently - 
	$text =~ s/<[^ID](?:[^>'"]*|(['"]).*?\1)*>//gs;
	$text =~ s/<ID/</gs;
	
	# Remove any extra spaces FIXME: Clear up final settings, like gsi - when are those really necessary? 
	$text =~ s/[ ]{2,10}/ /gis;
	
	# FIXME: Clear out orphan ID tags 
	#$text =~ s/^<[^<]+?>$//g;
	# Get rid of blank lines
	#$text =~ s/^\n$//g;	
	
	return $text;
}



##########################################################
# Parse the xml for all comments and save them in a hash
##########################################################

my %comments;
foreach my $comment (reverse($xc->findnodes('//post:entry'))) {
	my $type = $xc->findvalue('./post:category/@term', $comment);
	if ($type =~ /comment/) {
		my $content = ($xc->findvalue('./post:content', $comment) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $comment);
		my $author = $xc->findvalue('./post:author/post:name', $comment);
		my $date = cleanDate($xc->findvalue('./post:published', $comment));
		my $posturl = $xc->findvalue('./*[name()="thr:in-reply-to"]/@href', $comment);
		my $fullComment = "$date~~~$author~~~$content";
		$fullComment = cleanText($fullComment, 'comment');
		
		# Store it all in the hash
		push @{$comments{$posturl}}, $fullComment;
	}
}


####################################
# Clean up and organize blog posts
####################################

# Start InDesign tagged text
my $output = $IDstart;

# Reverse and loop through all the blog entries in the XML file
foreach my $entry (reverse($xc->findnodes('//post:entry'))) {
	my $type =  $xc->findvalue('./post:category[1]/@term', $entry);
	my $date = $xc->findvalue('./post:published', $entry);
	my $checkyear = getYear($date);
	if (($type =~ /post/) && ($checkyear eq $setyear)) {
		my $title = ($xc->findvalue('./post:title', $entry) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $entry);
		my $content = ($xc->findvalue('./post:content', $entry) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $entry);
		my $author = $xc->findvalue('./post:author/post:name', $entry);
		$date = cleanDate($date);
		my $commentsNum = $xc->findvalue('./post:link[2]/@title', $entry);
		my $posturl = $xc->findvalue('./post:link[5]/@href', $entry);
		# TODO: Get categories
		# Get all the post:category entries except [1]
		# TODO: Indexing
		# Possible ID index syntax = <IndexEntry:=<IndexEntryType:IndexPageEntry><IndexEntryRangeType:kCurrentPage><IndexEntryDisplayString:Test>>
		
		$output .= "\n\n$IDtitle$title\n";
		$output .= "$IDurl$posturl\n";
		$output .= "$IDdate$date\n";
		$output .= "$IDauthor$author\n";
		
		$content = cleanText($content, 'post');
		
		# Print the final content variable, preceded with ID First paragraph style
		$output .= "$IDfirst$content\n";
		
		
		############################
		# Add comments to the post
		############################
		 
		my $comments = '';
		
		foreach my $c (@{$comments{$posturl}}) {
			my @process_comment = split(/~~~/, $c);
			my $commentDate = $process_comment[0];
			my $commentAuthor = $process_comment[1];
			my $commentBody = $process_comment[2];
			$comments .= "$IDcommentauthor$commentAuthor\n";
			$comments .= "$IDcommentdate$commentDate\n";
			$comments .= "$IDcommentpara$commentBody\n";
		}
		
		# If there are comments print them out
		if ($comments ne '') {
			$output .= $comments;
		}
	}
}

# Print everything out
# open(OUTPUT, ">:encoding(utf16le)", "output.txt");
# print OUTPUT $output;
print $output;

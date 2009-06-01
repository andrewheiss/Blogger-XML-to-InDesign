#!/usr/bin/perl -w
# FUTURE: Why do I keep getting this error: Can't find string terminator '"' anywhere before EOF at -e line 1.
use strict;
use warnings;
use diagnostics;
binmode(STDOUT, ':utf8'); # Set STDOUT encoding to unicode for testing


#---------------------
# Dependent packages
#---------------------

# To get to the CPAN shell: "perl -MCPAN -e shell" and then "install Package::Name"
use Date::Format;
use Date::Parse;
use XML::LibXML;
use XML::LibXML::XPathContext;


#-----------------------
# Main setup variables
#-----------------------

# Select what year to extract FUTURE: Allow for a range of dates rather than just a year
my $setyear = "2009";

# Set the XML file to be parsed and cleaned FUTURE: Maybe allow this to be run via command line arguments as well
my $file = 'files/blog-tiny.xml';


#----------------------------
# InDesign Tagged Text tags
#----------------------------

# These tags all follow the IDTT format standard. See http://livedocs.adobe.com/en_US/InDesign/5.0/tagged_text.pdf for full documentation
# If you want the tag to remain in the file when you place the text, the style referenced must already exist in the InDesign file

# !!! IMPORTANT !!!
# Because of the text cleanup functions that remove HTML tags from the blog data, the two tildes (~~) serve as dummy text in the tag
# If you add any tags here, make sure two tildes come after the initial <, otherwise the tag will be cut from the final output

my $IDstart = "<~~UNICODE-MAC>\n";
my $IDtitle = "<~~ParaStyle:Post Title>";
my $IDurl = "<~~ParaStyle:Post URL>";			
my $IDdate = "<~~ParaStyle:Post Date>";
my $IDauthor = "<~~ParaStyle:Post Author>";
my $IDparagraph = "<~~ParaStyle:Main text>";
my $IDfirst = "<~~ParaStyle:First paragraph>";
my $IDtags = "<~~ParaStyle:Post tags>";
my $IDlist = "<~~ParaStyle:List>";
my $IDcommentpara = "<~~ParaStyle:Comments\\:Comment text>";
my $IDcommentauthor = "<~~ParaStyle:Comments\\:Comment author>";
my $IDcommentdate = "<~~ParaStyle:Comments\\:Comment date>";
my $IDfootstart = "<~~cPosition:Superscript><~~FootnoteStart:>";
my $IDfootend = "<~~FootnoteEnd:><~~cPosition:>";
my $IDcharend = "<~~CharStyle:>";
my $IDitalic = "<~~CharStyle:Italic>";
my $IDbold = "<~~CharStyle:Bold>";
my $IDsmall = "<~~CharStyle:Small>";
my $IDsmallitalic = "<~~CharStyle:Small italic>";


#--------------
# Get started
#--------------

# Connect to XML file and create LibXML object with the Atom namespace
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($file);
my $xc = XML::LibXML::XPathContext->new($doc->documentElement());
$xc->registerNs(post => 'http://www.w3.org/2005/Atom');

#----------------------------------------------------------------------------
#
#	Sub name: getYear
#	Purpose: Gets only the year out of Blogger's date to be used in reorganizePosts() and limit post extraction to one year
#	Incoming parameters: Blogger's date - 2008-02-29T08:50:00.000-08:00
#	Returns: A four digit year
#	Dependencies: Date::Format, Date::Parse
#
#----------------------------------------------------------------------------

sub getYear($) {
	my $date= $_[0];
	$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g;
	$date = time2str("%Y", str2time($date), "0");
	return $date;
}



#----------------------------------------------------------------------------
#
#	Sub name: cleanDate
#	Purpose: Transform the date provided by Blogger into a string that can be used by Date::Parse's str2ime()
#	Incoming parameters: Blogger's date - 2008-02-29T08:50:00.000-08:00
#	Returns: Cleaned up date
#	Dependencies: Date::Format, Date::Parse
#
#----------------------------------------------------------------------------

sub cleanDate($) {
	my $date= $_[0];
	
	#------------------------------------------------------------------------
	# Time zone issues:
	# Blogger decides the time zone offset based on the global time zone blog setting rather than GMT
	# So, if you publish a post in MST, the timestamp will end in -07:00
	# If you change the time zone setting on your blog, all previous posts will change as well; the post done in MST will change to the new zone
	# To deal with this, either change the time zone setting in the Blogger settings to the desired time zone before you export the full file
	# Or, set the time zone manually as $timezone
	# The best solution is to export the blog while it is set in the desired timezone. 
	# If there are mutliple timezones in the year, download several copies of the backup, run this on all of them, and combine them in InDesign as necessary
	# It's extremely messy and convoluted but it's the only workaround I've found for now.
	# FUTURE: Simplify this
	#------------------------------------------------------------------------
	
	my $timezone = $date;
	$timezone =~ s/.*T.{12}(.){1}(\d\d):(\d\d)/$1$2$3/; # Extract the time zone
	$timezone = (substr($timezone, 0, 1) eq '+') ? substr($timezone,1,length($timezone)) : $timezone; # Cut off the initial + if there is one

	# Uncomment the next line if you want to override the time zone manually. This will kill DST calculations, unfortunately
	#$timezone = "0200"; # Use "NNNN" for +NN:NN, "-NNNN" for -NN:NN
	
	$date =~ s/\.[0-9]{3}-[0-9|:]{5}|T/ /g; # Clear out the miliseconds and everything that comes after in the timestamp
	$date = time2str("%A, %B %e, %Y - %l:%M %p", str2time($date), $timezone); # See http://search.cpan.org/dist/TimeDate/lib/Date/Format.pm for time2str formatting variables
	return $date;
}



#----------------------------------------------------------------------------
#
#	Sub name: cleanText
#	Purpose: Take out html tags, remove spaces, and generally clean up a string
#	Incoming parameters: Text to be cleaned as $text, optional $type - use 'comment' to put appropriate styles in comments
#	Returns: Cleaned up text
#	Dependencies: None
#
#----------------------------------------------------------------------------

# FIXME: Figure out why this isn't completely working. Doesn't work with newlines, since they apparently don't exist?

sub cleanText {
	my $text = $_[0];
	my $type = defined $_[1] ? $_[1] : 'post'; # Makes the default text type 'post'
	
	# If cleaning a comment, use the comment styles - otherwise use regular styles
	my $IDcleanpara = ($type eq 'comment') ? $IDcommentpara : $IDparagraph ;
	
	# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
	# Find any sequence of <br>s and replace with a new line; replace <p>s with ID tags
	$text =~ s/(<br\s?[\/]?>)+/\n$IDcleanpara/gis;
	$text =~ s/<p[^>]*>(.*?)<\/p>/\n$IDcleanpara$1/gis;
	
	# Find href="" in all links and linked text - strip out the rest of the HTML - put link in footnote
	$text =~ s/<a\s[^>]*href=["']+?([^["']*)["']+?[^>]*>(.*?)<\/a>/$2$IDfootstart$1$IDfootend/gis; # Both quotes (href="" & href='')
	
	# Find images, keep src link, strip the rest out
	$text =~ s/<img\s[^>]*src=["']+?([^["']*)["']+?[^>]*>/{$1}/gis;
	
	# Make any span with font-size in it smaller. It's not all really small, and there are different levels blogger uses. 78% seems to be the most common
	# FUTURE: Make me more flexible - find the current and historical blogger sizes
	$text =~ s/<span[^>]*?font-size[^>]*>(.*?)<\/span>/$IDsmall$1$IDcharend/gis;
	
	# Take care of <li>s
	$text =~ s/<li[^>]*>(.*?)<\/li>/\n$IDlist$1/gis;
	
	# Italicize text between <i>, <em>, and any span with the word italic in any attribute
	$text =~ s/<span[^>]*?italic[^>]*>(.*?)<\/span>/$IDitalic$1$IDcharend/gis;
	$text =~ s/<i>(.*?)<\/i>/$IDitalic$1$IDcharend/gis; 
	$text =~ s/<em>(.*?)<\/em>/$IDitalic$1$IDcharend/gis;
	
	# Bold text between <b>, <strong>, and any span with the word bold in any attribute
	$text =~ s/<span[^>]*?bold[^>]*>(.*?)<\/span>/$IDbold$1$IDcharend/gis;
	$text =~ s/<b>(.*?)<\/b>/$IDbold$1$IDcharend/gis; 
	$text =~ s/<strong>(.*?)<\/strong>/$IDbold$1$IDcharend/gis;
	
	# FIXME: ID can't handle nested character styles - combine them when necessary
	# $text =~ s/\Q$IDsmall\Q$IDitalic/$IDsmallitalic/gi;
	# $text =~ s/\Q$IDcharend\Q$IDcharend/$IDcharend/gi;
	# $text =~ s/<CharStyle:Small><CharStyle:Italic>/$IDsmallitalic/gi;
	# $text =~ s/<CharStyle:><CharStyle:>/$IDcharend/gi;
	
	# Clear out any tags that aren't the InDesign tags, take out the dummy ~~ and rebuild the actual tag
	$text =~ s/<[^~~](?:[^>'"]*|(['"]).*?\1)*>//gs;
	$text =~ s/<~~/</gs;
	
	# FUTURE: Add replacements for em, en dashes, ellipses with non breaking spaces
	
	# Remove any extra spaces
	$text =~ s/[ ]{2,10}/ /gis;
	
	# FIXME: Clear out orphan ID tags 
	# $text =~ s/^<[^<]+?>$//g;
	# $text =~ s/^<.*?[^>]>$//gis;
	
	# FIXME: Get rid of blank lines
	# $text =~ s/^\n$//g;
	
	return $text;
}



#----------------------------------------------------------------------------
#
#	Sub name: organizeComments
#	Purpose: Parse the XML file for all comments and save them in an indexed hash
#	Incoming parameters: None
#	Returns: %comments hash
#	Dependencies: XML::LibXML, XML::LibXML::XPathContext;
#
#----------------------------------------------------------------------------

sub organizeComments {
	my %comments;
	foreach my $comment (reverse($xc->findnodes('//post:entry'))) {
		my $type = $xc->findvalue('./post:category/@term', $comment);
		if ($type =~ /comment/) {
			my $content = ($xc->findvalue('./post:content', $comment) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $comment);
			my $author = $xc->findvalue('./post:author/post:name', $comment);
			my $date = cleanDate($xc->findvalue('./post:published', $comment));
			my $posturl = $xc->findvalue('./*[name()="thr:in-reply-to"]/@href', $comment);
			# Save comment with temporary ~~~ delimiting
			my $fullComment = "$date~~~$author~~~$content";
		
			# Store it all in the hash
			push @{$comments{$posturl}}, $fullComment;
		}
	}
	
	return %comments;
}



#----------------------------------------------------------------------------
#
#	Sub name: reorganizePosts
#	Purpose: Parse the XML file for all blog posts, query the %comments and connect matching comments to the post, tag and clean the text
#	Incoming parameters: None
#	Returns: $output - cleaned, formatted, and tagged text
#	Dependencies: XML::LibXML, XML::LibXML::XPathContext;
#
#----------------------------------------------------------------------------

sub reorganizePosts {

	my %comments = organizeComments;

	# Start InDesign tagged text
	my $output = $IDstart;

	# Reverse and loop through all the blog entries in the XML file
	foreach my $entry (reverse($xc->findnodes('//post:entry'))) {
		my $type =  $xc->findvalue('./post:category[1]/@term', $entry);
		my $checkyear = getYear($xc->findvalue('./post:published', $entry));
		if (($type =~ /post/) && ($checkyear eq $setyear)) {
		
		
			#--------------------------
			# Get text out of the XML
			#--------------------------
			
			my $title = ($xc->findvalue('./post:title', $entry) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $entry);
			my $content = ($xc->findvalue('./post:content', $entry) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $entry);
			my $author = $xc->findvalue('./post:author/post:name', $entry);
			my $date = cleanDate($xc->findvalue('./post:published', $entry));
			my $posturl = $xc->findvalue('./post:link[5]/@href', $entry);
		
			# Get all the post:category entries except [1], since that indicates the type of entry
			my $tags = '';
			foreach my $tag ($xc->findnodes('./post:category[position()>1]/@term', $entry)) {
				$tags .= ucfirst(($tag->to_literal)) . ", ";
			}

			# FUTURE: Indexing
			# Possible ID index syntax = <IndexEntry:=<IndexEntryType:IndexPageEntry><IndexEntryRangeType:kCurrentPage><IndexEntryDisplayString:Test>>
			
			
			#----------------------------------
			# Put extracted text into $output
			#----------------------------------
			
			$output .= "\n\n$IDtitle$title\n"; 	# Title
			$output .= "$IDurl$posturl\n"; 		# URL
			$output .= "$IDdate$date\n"; 		# Date
			$output .= "$IDauthor$author\n"; 	# Author
		
			if ($tags ne '') { # Tags
				$tags = substr($tags, 0, -2); 	# Cut off trailing comma and space
				$output .= "$IDtags$tags\n";
			}
		
			$output .= "$IDfirst$content\n";	# Content with ID First paragraph style
		
		
			#-----------------------------------------
			# Add corresponding comments to the post
			#-----------------------------------------
		 
			my $comments = '';
		
			foreach my $c (@{$comments{$posturl}}) {
				my @process_comment = split(/~~~/, $c);
				my $commentDate = $process_comment[0];
				my $commentAuthor = $process_comment[1];
				my $commentBody = $process_comment[2];
				$comments .= "$IDcommentauthor$commentAuthor\n";	# Comment author
				$comments .= "$IDcommentdate$commentDate\n";		# Comment date
				$comments .= "$IDcommentpara$commentBody\n";		# Comment text
			}
		
			# If there are comments print them out
			if ($comments ne '') {
				$output .= $comments;
			}
		}
	}
	
	$output = cleanText($output);
	
	return $output;
}



#--------------------------------------------------
# Parse the XML, clean up the text and output it.
#--------------------------------------------------

# Open output file, set encoding to unicode - InDesign needs UTF16 Little Endian
# open(OUTPUT, ">:encoding(utf16le)", "output.txt");
# print OUTPUT reorganizePosts;
print reorganizePosts;
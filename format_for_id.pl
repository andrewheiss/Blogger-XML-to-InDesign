#!/usr/bin/perl -w
use strict;
use warnings;
use diagnostics;
binmode(STDOUT, ':utf8'); # Set STDOUT encoding to unicode for testing


#---------------------
# Dependent packages
#---------------------

# To get to the CPAN shell: "perl -MCPAN -e shell" and then "install Package::Name"
# See http://search.cpan.org/dist/TimeDate/lib/Date/Format.pm for time2str formatting variables
use Date::Format; 
use Date::Parse;
# FUTURE: Use XML::Twig or something else to parse both the XML and the extracted HTML and replace all the regexes with parsed variables
use XML::LibXML;
use XML::LibXML::XPathContext;
use HTML::Entities;


#-----------------------
# Main setup variables
#-----------------------

# Select what year to extract | FUTURE: Allow for a range of dates rather than just a year, using new pseudoTimestamp() sub
my $setyear = "2009";

# Set the XML file to be parsed and cleaned | FUTURE: Maybe allow this to be run via command line arguments as well
my $file = 'files/blog-tiny.xml';


#----------------------------
# InDesign Tagged Text tags
#----------------------------

# These tags all follow the IDTT format standard. See http://livedocs.adobe.com/en_US/InDesign/5.0/tagged_text.pdf for full documentation
# If you want the tag to remain in the file when you place the text, the style referenced must already exist in the InDesign file

# !!! IMPORTANT !!!
# Because of the text cleanup functions that remove HTML tags from the blog data, the two tildes (~~) serve as dummy text in the tag
# If you add any tags here, make sure two tildes come after the initial <, otherwise the tag will be cut from the final output
# The only exception to the two tilde rule is $IDstart, which doesn't go through an cleanup function

my $IDstart = "<UNICODE-MAC>";
my $IDtitle = "<~~ParaStyle:Post Title>";
my $IDurl = "<~~ParaStyle:Post URL>";			
my $IDdate = "<~~ParaStyle:Post Date>";
my $IDauthor = "<~~ParaStyle:Post Author>";
my $IDparagraph = "<~~ParaStyle:Main text>";
my $IDfirst = "<~~ParaStyle:First paragraph>";
my $IDtags = "<~~ParaStyle:Post tags>";
my $IDlist = "<~~ParaStyle:List>";
my $IDblock = "<~~ParaStyle:Block quote>";
my $IDsubhead = "<~~ParaStyle:Sub head>";
my $IDcommentpara = "<~~ParaStyle:Comments\\:Comment text>";
my $IDcommentauthor = "<~~ParaStyle:Comments\\:Comment author>";
my $IDcommentdate = "<~~ParaStyle:Comments\\:Comment date>";
my $IDsupstart = "<~~cPosition:Superscript>";
my $IDsupend = "<~~cPosition:>";
my $IDfootstart = "<~~cPosition:Superscript><~~FootnoteStart:>";
my $IDfootend = "<~~FootnoteEnd:><~~cPosition:>";
my $IDcharend = "<~~CharStyle:>";
my $IDitalic = "<~~CharStyle:Italic>";
my $IDbold = "<~~CharStyle:Bold>";
my $IDsmall = "<~~CharStyle:Small>";
my $IDsmallitalic = "<~~CharStyle:Small italic>";
my $IDsmallbold = "<~~CharStyle:Small bold>";


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

sub getYear {
	my $date= $_[0];
	$date = time2str("%Y", str2time($date), "0");
	return $date;
}


#----------------------------------------------------------------------------
#
#	Sub name: pseudoTimestamp
#	Purpose: Remove all punctuation from Blogger's timestamp:
#		2009-04-10T18:51:04.696+02:00 becomes 20090410185104
#		Used for sorting entries correctly
#	Incoming parameters: Blogger formatted date
#	Returns: $date - Blogger's Atom timestamp without punctuation
#
#----------------------------------------------------------------------------

sub pseudoTimestamp {
    my $date = $_[0];
    $date = join "", $date =~ m!\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}).*!;
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

sub cleanDate {
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
	
	$date = time2str("%A, %B %e, %Y | %l:%M %p", str2time($date), $timezone); 
	return $date;
}


#----------------------------------------------------------------------------
#
#	Sub name: makeParagraphs
#	Purpose: Replace <br>s and <p>s with correct tags
#	Incoming parameters: Text to be divided as $text, optional $type - use 'comment' to put appropriate styles in comments
#	Returns: Tag-delimited text
#	Dependencies: None
#
#----------------------------------------------------------------------------

sub makeParagraphs {
	my $text = $_[0];
	my $type = defined $_[1] ? $_[1] : 'post'; # Makes the default text type 'post'
	
	# If cleaning a comment, use the comment styles - otherwise use regular styles
	my $IDcleanpara = ($type eq 'comment') ? $IDcommentpara : $IDparagraph ;
	
	$text =~ s/<h[1-6][^>]*>(.*?)<\/h[1-6]>/\n$IDsubhead$1/gis;
	
	# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
	# Find any sequence of <br>s and replace with a new line; replace <p>s with ID tags
	$text =~ s/(<br\s?[\/]?>)+/\n$IDcleanpara/gis;
	$text =~ s/<p[^>]*>(.*?)<\/p>/\n$IDcleanpara$1/gis;
	
	return $text;
}


#----------------------------------------------------------------------------
#
#	Sub name: cleanText
#	Purpose: Take out html tags, remove spaces, and generally clean up a string
#	Incoming parameters: Text to be cleaned as $text
#	Returns: Cleaned up text
#	Dependencies: None
#
#----------------------------------------------------------------------------

sub cleanText {
	my $text = $_[0];
	
	# Find href="" in all links and linked text - strip out the rest of the HTML - put link in footnote
	$text =~ s/<a\s[^>]*href=["']+?([^["']*)["']+?[^>]*>(.*?)<\/a>/$2$IDfootstart$1$IDfootend/gis; # Both quotes (href="" & href='')
	
	# Find images, keep src link, strip the rest out
	$text =~ s/<img\s[^>]*src=["']+?([^["']*)["']+?[^>]*>/{$1}/gis;
	
	# Make any span with font-size in it smaller. It's not all really small, and there are different levels blogger uses. 78% seems to be the most common
	# FUTURE: Make me more flexible - find the current and historical blogger sizes?
	$text =~ s/<span[^>]*?font-size[^>]*>(.*?)<\/span>/$IDsmall$1$IDcharend/gis;
	
	# Take care of <li>s, <blockquote>s, and <sup>s
	$text =~ s/<li[^>]*>(.*?)<\/li>/\n$IDlist$1/gis;
	$text =~ s/<blockquote[^>]*>(.*?)<\/blockquote>/$IDblock$1/gism;
	$text =~ s/<sup[^>]*>(.*?)<\/sup>/$IDsupstart$1$IDsupend/gis;
	
	# Italicize text between <i>, <em>, and any span with the word italic in any attribute
	$text =~ s/<span[^>]*?italic[^>]*>(.*?)<\/span>/$IDitalic$1$IDcharend/gis;
	$text =~ s/<i>(.*?)<\/i>/$IDitalic$1$IDcharend/gis; 
	$text =~ s/<em>(.*?)<\/em>/$IDitalic$1$IDcharend/gis;
	
	# Bold text between <b>, <strong>, and any span with the word bold in any attribute
	$text =~ s/<span[^>]*?bold[^>]*>(.*?)<\/span>/$IDbold$1$IDcharend/gis;
	$text =~ s/<b>(.*?)<\/b>/$IDbold$1$IDcharend/gis; 
	$text =~ s/<strong>(.*?)<\/strong>/$IDbold$1$IDcharend/gis;
	
	# ID can't handle nested character styles - combine them when necessary
	$text =~ s/\Q$IDsmall\E\Q$IDitalic\E/$IDsmallitalic/gi;
	$text =~ s/\Q$IDsmall\E\Q$IDbold\E/$IDsmallbold/gi;
	$text =~ s/(\Q$IDcharend\E)\1+/$1/gi;
	
	# Add em dashes (2014), en dashes (2013), and ellipses (..., . . .,  or 2026) with non breaking spaces (00A0)
	$text =~ s/--| - /\x{2014}/gis;
	$text =~ s/([0-9])-([0-9])/$1\x{2013}$2/gis;
	$text =~ s/([\.\?!,:;])[ ]?\.[ ]?\.[ ]?\.[ ]?|([\.\?!,:;])[ ]?\x{2026}[ ]?/$1\x{00A0}.\x{00A0}.\x{00A0}. /gis; # 4 dot elipses (after punctuation)
	$text =~ s/[ ]?\.[ ]?\.[ ]?\.[ ]?|[ ]?\x{2026}[ ]?/\x{00A0}.\x{00A0}.\x{00A0}. /gis; # 3 dot elipses
	
	# FUTURE: Indexing?
	# Possible ID index syntax = <IndexEntry:=<IndexEntryType:IndexPageEntry><IndexEntryRangeType:kCurrentPage><IndexEntryDisplayString:Test>>
	
	# Clear out any xml and stylesheets left by Word
	$text =~ s/<style>(.*?)<\/style>//gi;
	$text =~ s/<xml>(.*?)<\/xml>//gi;
	
	# Clear out any tags that aren't the InDesign tags, take out the dummy ~~ and rebuild the actual tag
	$text =~ s/<[^~]{2}(?:[^>'"]*|(['"]).*?\1)*>//gs;
	$text =~ s/<~{2}/</gs;
	
	# Clear out orphan ID tags 
	# $text =~ s/^<[^<|\Q$realstart\E]+?>$//gsm;
	$text =~ s/^<[^<]+?>$//gsm;
	
	# Replace 2 or more new lines or spaces with nothing
	$text =~ s/([\n ])\1+/$1/gsm;
	
	# Take care of any stray HTML entities
	decode_entities($text);
	
	return $text;
}



#----------------------------------------------------------------------------
#
#	Sub name: collectComments
#	Purpose: Parse the XML file for all comments and save them in an indexed hash
#	Incoming parameters: None
#	Returns: %comments hash
#	Dependencies: XML::LibXML, XML::LibXML::XPathContext;
#
#----------------------------------------------------------------------------

sub collectComments {
	my %comments;
	foreach my $comment (reverse($xc->findnodes('//post:entry'))) {
		my $type = $xc->findvalue('./post:category/@term', $comment);
		if ($type =~ /comment/) {
			my $content = ($xc->findvalue('./post:content', $comment) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $comment);
			my $author = $xc->findvalue('./post:author/post:name', $comment);
			my $date = cleanDate($xc->findvalue('./post:published', $comment));
			my $posturl = $xc->findvalue('./*[name()="thr:in-reply-to"]/@href', $comment);
			
			# Save comment with temporary ~~~ delimiting | FUTURE: Store it as an array instead
			my $fullComment = "$date~~~$author~~~$content";
		
			# Store it all in the hash
			push @{$comments{$posturl}}, $fullComment;
		}
	}
	
	return %comments;
}


#----------------------------------------------------------------------------
#
#	Sub name: collectPosts
#	Purpose: Parse the XML file for all blog posts, save all the retrieved data as an array in an indexed hash
#	Incoming parameters: None
#	Returns: %posts - %hash = ($date => [ '$value1', '$value2', '$value3' ],...)
#	Dependencies: XML::LibXML, XML::LibXML::XPathContext;
#
#----------------------------------------------------------------------------

sub collectPosts {
	my %posts;
	
	# Loop through all the blog entries in the XML file and collect them if they meet certain parameters
	foreach my $post ($xc->findnodes('//post:entry')) {
		my $type = $xc->findvalue('./post:category/@term', $post);
		my $checkyear = getYear($xc->findvalue('./post:published', $post));
		
		if (($type =~ /post/) && ($checkyear eq $setyear)) {
		
			#----------------------------------------------------------------------------
			# Get text out of the XML if there's an actual URL (the post was published)
			#----------------------------------------------------------------------------
			
			my $posturl = $xc->findvalue('./post:link[5]/@href', $post);
			
			if ($posturl ne '') {
				my @array;
			
				my $date = pseudoTimestamp($xc->findvalue('./post:published', $post));
			
				my $title = ($xc->findvalue('./post:title', $post) eq '') ? 'Untitled post' : $xc->findvalue('./post:title', $post);
				my $content = ($xc->findvalue('./post:content', $post) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $post);
				my $author = $xc->findvalue('./post:author/post:name', $post);
				my $cleandate = cleanDate($xc->findvalue('./post:published', $post));
				my $posturl = $xc->findvalue('./post:link[5]/@href', $post);
			
				# Get all the post:category entries except [1], since that indicates the type of entry
				my $tags = '';
				foreach my $tag ($xc->findnodes('./post:category[position()>1]/@term', $post)) {
					$tags .= ucfirst(($tag->to_literal)) . ", ";
				}
				
				# If there are tags, cut off the trailing comma and space
				if ($tags ne '') { 
					$tags = substr($tags, 0, -2); 
				}
			
				# Save everything into an array
				@array = ($title, $content, $author, $cleandate, $posturl, $tags);
		
				# Store store the array into a hash indexed by the timestamp
				push @{$posts{$date}}, @array;
			}
		}
	}
	
	return %posts;
}


#----------------------------------------------------------------------------
#
#	Sub name: combineSortClean
#	Purpose: Sort the posts, clean up all text, connect comments with posts
#	Incoming parameters: None
#	Returns: $output - cleaned, formatted, and tagged text
#	Dependencies: None
#
#----------------------------------------------------------------------------

sub combineSortClean {
	my %comments = collectComments;
	my %posts = collectPosts;
	
	# Start InDesign tagged text
	# my $output = "$IDstart\n";
	my $output = "";
	
	# Sort the posts
	foreach my $key (sort { $a <=> $b } (keys(%posts))) {
		
		#------------------------------------------------------
		# Extract variables from the array stored in the hash
		#------------------------------------------------------
		
		my $title = $posts{$key}[0];
		my $content = $posts{$key}[1];
		my $author = $posts{$key}[2];
		my $date = $posts{$key}[3];
		my $posturl = $posts{$key}[4];
		my $tags = $posts{$key}[5];
		
		
		#----------------------------------
		# Put extracted text into $output
		#----------------------------------
		
		$output .= "$IDtitle$title\n"; 		# Title
		$output .= "$IDurl$posturl\n"; 		# URL
		$output .= "$IDdate$date\n"; 		# Date
		$output .= "$IDauthor$author\n"; 	# Author
		$output .= "$IDtags$tags\n";		# Tags
		
		$content = makeParagraphs($content);
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
			$output .= makeParagraphs($comments, "comment");
		}

	}
	
	
	#---------------------------------------
	# Add file header and clean up $output
	#---------------------------------------
	
	$output = "$IDstart\n" . cleanText($output);
	
	return $output;
}


#--------------------------------------------------
# Parse the XML, clean up the text and output it.
#--------------------------------------------------

# Open output file, set encoding to unicode - InDesign needs UTF16 Little Endian
# open(OUTPUT, ">:encoding(utf16le)", "output.txt");
# print OUTPUT combineSortClean;
print combineSortClean;
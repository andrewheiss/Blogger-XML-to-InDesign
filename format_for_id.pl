#!/usr/bin/perl -w
use strict;
use warnings;
use diagnostics;
use subs qw(combineSortClean);


#--------------------------
# Dependent CPAN packages
#--------------------------

# To get to the CPAN shell:
# -Mac OS X: "perl -MCPAN -e shell" 
# -Linux: "sudo cpan"
# -Windows: Use Stawberry Perl and the packaged CPAN Client
# ... then type "install Package::Name"

# See http://search.cpan.org/dist/TimeDate/lib/Date/Format.pm for time2str formatting variables
use Date::Format; 
use Date::Parse;
# FUTURE: Use XML::Twig or something else to parse both the XML and the extracted HTML and replace all the regexes with parsed variables
use XML::LibXML;
use XML::LibXML::XPathContext;
use HTML::Entities;
use Config::General;


#------------------------
# Run the actual script
#------------------------

# Connect to the .cfg file and get settings
my $cfgfile = "config.cfg";
my $conf = new Config::General($cfgfile);
my %config = $conf->getall;

# Connect to XML file and create LibXML object with the Atom namespace
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file($config{input}{file});
my $xc = XML::LibXML::XPathContext->new($doc->documentElement());
$xc->registerNs(post => 'http://www.w3.org/2005/Atom');

# Escape the $config{tags} hash and save it as %ID
my %ID;
for my $tag ($config{tags}){
	my ($key, $value);
	while (($key, $value) = each %{$tag}) {
		$ID{$key} = escapeID($value);
	}
}

# Parse the XML, clean up the text, and output it
if ($config{testing} == 0) {
	# Open output file, set encoding to unicode - InDesign needs UTF16 Little Endian. 
	# :raw layer needs to be enabled for proper newlines in Windows (I have no idea why, though)
	open(OUTPUT, ">:raw:encoding(utf16le)", $config{output}{file});
	print OUTPUT combineSortClean;
} else {
	binmode(STDOUT, ':utf8'); # Set STDOUT encoding to unicode for testing
	print combineSortClean;
}


#-------------------------------------
# Helper functions to run the script 
#-------------------------------------

# FUTURE: Rewrite this all as a class. It already essentially is one--all the functions would be private except combineSortClean(). 

#------------------------------------
#
#	Sub name: escapeID
#	Purpose: Add tildes in the $ID{}* variables 
#	Incoming parameters: An $ID{}* variable in standard format: <ParaStyle:Post Title>
#	Returns: $fix - Tilde-escaped string: <~~ParaStyle:Post Title>
#
#------------------------------------

sub escapeID {
	my $fix = $_[0];
	$fix =~ s/(<)(.*?>)/$1~~$2/gis;	# Add tildes
	return trim($fix);
}


#------------------------------------
#
#	Sub name: trim
#	Purpose: Replicate PHP's trim() - trim whitespace from the beginning and end of the string
#	Incoming paramter: Any string
#	Returns: $string - Trimmed $string
#
#------------------------------------

sub trim {
	my $string = $_[0];
	$string =~ s/^\s+|\s+$//g;
	return $string;
}


#------------------------------------
#
#	Sub name: getYear
#	Purpose: Gets only the year out of Blogger's date to be used in reorganizePosts() and limit post extraction to one year
#	Incoming parameter: Blogger's Atom timestamp - 2008-02-29T08:50:00.000-08:00
#	Returns: $date - A four digit year
#	Dependencies: Date::Format, Date::Parse
#
#------------------------------------

sub getYear {
	my $date= $_[0];
	$date = time2str("%Y", str2time($date), "0");
	return $date;
}


#------------------------------------
#
#	Sub name: pseudoTimestamp
#	Purpose: Remove all punctuation from Blogger's timestamp - used for sorting entries chronologically
#	Incoming parameter: Blogger's Atom timestamp - 2009-04-10T18:51:04.696+02:00
#	Returns: $date - Timestamp without punctuation - 20090410185104
#
#------------------------------------

sub pseudoTimestamp {
    my $date = $_[0];
    $date = join "", $date =~ m!\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}).*!;
    return $date;
}


#------------------------------------
#
#	Sub name: cleanDate
#	Purpose: Transform the date provided by Blogger into a string that can be used by Date::Parse's str2ime()
#	Incoming parameters: Blogger's Atom timestamp - 2008-02-29T08:50:00.000-08:00
#	Returns: $date - Cleaned up, human readable date
#	Dependencies: Date::Format, Date::Parse
#
#------------------------------------

sub cleanDate {
	my $date= $_[0];
	
	#------------------------------------
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
	#------------------------------------
	
	my $timezone = $date;
	$timezone =~ s/.*T.{12}(.){1}(\d\d):(\d\d)/$1$2$3/; # Extract the time zone
	$timezone = (substr($timezone, 0, 1) eq '+') ? substr($timezone,1,length($timezone)) : $timezone; # Cut off the initial + if there is one

	# Uncomment the next line if you want to override the time zone manually. This will kill DST calculations, unfortunately
	#$timezone = "0200"; # Use "NNNN" for +NN:NN, "-NNNN" for -NN:NN
	
	$date = time2str("%A, %B %e, %Y | %l:%M %p", str2time($date), $timezone); 
	return $date;
}


#------------------------------------
#
#	Sub name: makeParagraphs
#	Purpose: Replace <br>s and <p>s with correct InDesign tags
#	Incoming parameters: Text to be divided as $text, 
#		Optional $type - use 'comment' to put appropriate styles in comments
#	Returns: $text - Tag-delimited text
#	Dependencies: None
#
#------------------------------------

sub makeParagraphs {
	my $text = $_[0];
	my $type = defined $_[1] ? $_[1] : 'post'; # Makes the default text type 'post'
	
	# If cleaning a comment, use the comment styles - otherwise use regular styles
	my $cleanpara = ($type eq 'comment') ? $ID{commentpara} : $ID{paragraph} ;
	
	$text =~ s/<h[1-6][^>]*>(.*?)<\/h[1-6]>/\n$ID{subhead}$1/gis;
	
	# Assumes that a break means a real paragraph break and not just a soft return thanks to Blogger's newline interpretation in their CMS
	# Find any sequence of <br>s and replace with a new line; replace <p>s with ID tags
	$text =~ s/(<br\s?[\/]?>)+/\n$cleanpara/gis;
	$text =~ s/<p[^>]*>(.*?)<\/p>/\n$cleanpara$1/gis;
	
	return $text;
}


#------------------------------------
#
#	Sub name: cleanText
#	Purpose: Take out html tags, remove spaces, and generally clean up a string
#	Incoming parameters: Text to be cleaned as $text
#	Returns: $text - Cleaned up text
#	Dependencies: None
#
#------------------------------------

sub cleanText {
	my $text = $_[0];
	
	# Find href="" in all links and linked text - strip out the rest of the HTML - put link in footnote
	$text =~ s/<a\s[^>]*href=["']+?([^["']*)["']+?[^>]*>(.*?)<\/a>/$2$ID{footstart}$1$ID{footend}/gis; # Both quotes (href="" & href='')
	
	# Find images, keep src link, strip the rest out
	$text =~ s/<img\s[^>]*src=["']+?([^["']*)["']+?[^>]*>/{$1}/gis;
	
	# Make any span with font-size in it smaller. It's not all really small, and there are different levels blogger uses. 78% seems to be the most common
	# FUTURE: Make me more flexible - find the current and historical blogger sizes?
	$text =~ s/<span[^>]*?font-size[^>]*>(.*?)<\/span>/$ID{small}$1$ID{charend}/gis;
	
	# Take care of <li>s, <blockquote>s, and <sup>s
	$text =~ s/<li[^>]*>(.*?)<\/li>/\n$ID{list}$1/gis;
	$text =~ s/<blockquote[^>]*>(.*?)<\/blockquote>/$ID{block}$1/gism;
	$text =~ s/<sup[^>]*>(.*?)<\/sup>/$ID{supstart}$1$ID{supend}/gis;
	
	# Italicize text between <i>, <em>, and any span with the word italic in any attribute
	$text =~ s/<span[^>]*?italic[^>]*>(.*?)<\/span>/$ID{italic}$1$ID{charend}/gis;
	$text =~ s/<i>(.*?)<\/i>/$ID{italic}$1$ID{charend}/gis; 
	$text =~ s/<em>(.*?)<\/em>/$ID{italic}$1$ID{charend}/gis;
	
	# Bold text between <b>, <strong>, and any span with the word bold in any attribute
	$text =~ s/<span[^>]*?bold[^>]*>(.*?)<\/span>/$ID{bold}$1$ID{charend}/gis;
	$text =~ s/<b>(.*?)<\/b>/$ID{bold}$1$ID{charend}/gis; 
	$text =~ s/<strong>(.*?)<\/strong>/$ID{bold}$1$ID{charend}/gis;
	
	# ID can't handle nested character styles - combine them when necessary
	$text =~ s/\Q$ID{small}\E\Q$ID{italic}\E/$ID{smallitalic}/gi;
	$text =~ s/\Q$ID{small}\E\Q$ID{bold}\E/$ID{smallbold}/gi;
	$text =~ s/(\Q$ID{charend}\E)\1+/$1/gi;
	
	# Add em dashes (2014), en dashes (2013), and ellipses (..., . . .,  or 2026) with non breaking spaces (00A0)
	$text =~ s/--| - /\x{2014}/gis;
	$text =~ s/([0-9])-([0-9])/$1\x{2013}$2/gis;
	$text =~ s/([\.\?!,:;])[ ]?\.[ ]?\.[ ]?\.[ ]?|([\.\?!,:;])[ ]?\x{2026}[ ]?/$1\x{00A0}.\x{00A0}.\x{00A0}. /gis; # 4 dot elipses (after punctuation)
	$text =~ s/[ ]?\.[ ]?\.[ ]?\.[ ]?|[ ]?\x{2026}[ ]?/\x{00A0}.\x{00A0}.\x{00A0}. /gis; # 3 dot elipses
	
	# Clear out any xml and stylesheets left by Word
	$text =~ s/<style>(.*?)<\/style>//gi;
	$text =~ s/<xml>(.*?)<\/xml>//gi;
	
	# Clear out any tags that aren't the InDesign tags, take out the dummy ~~ and rebuild the actual tag
	$text =~ s/<[^~]{2}(?:[^>'"]*|(['"]).*?\1)*>//gs;
	$text =~ s/<~{2}/</gs;
	
	# Clear out orphan ID tags 
	$text =~ s/^<[^<]+?>$//gsm;
	
	# Replace 2 or more new lines or spaces with nothing
	$text =~ s/([\n ])\1+/$1/gsm;
	
	# Take care of any stray HTML entities
	decode_entities($text);
	
	return $text;
}


#------------------------------------
#
#	Sub name: collectComments
#	Purpose: Parse the XML file for all comments and save them in an indexed hash
#	Incoming parameters: None
#	Returns: %comments hash
#	Dependencies: XML::LibXML, XML::LibXML::XPathContext
#
#------------------------------------

sub collectComments {
	my %comments;
	foreach my $comment (reverse($xc->findnodes('//post:entry'))) {
		my $type = $xc->findvalue('./post:category/@term', $comment);
		if ($type =~ /comment/) {
			my $content = ($xc->findvalue('./post:content', $comment) eq '') ? 'No content in the post' : $xc->findvalue('./post:content', $comment);
			my $author = $xc->findvalue('./post:author/post:name', $comment);
			my $date = cleanDate($xc->findvalue('./post:published', $comment));
			my $posturl = $xc->findvalue('./*[name()="thr:in-reply-to"]/@href', $comment);
			
			# Save comment with temporary ~~~ delimiting
			# FUTURE: Store it as an array instead - trickier than I thought...
			my $fullComment = "$date~~~$author~~~$content";
		
			# Store it all in the hash
			push @{$comments{$posturl}}, $fullComment;
		}
	}
	
	return %comments;
}


#------------------------------------
#
#	Sub name: collectPosts
#	Purpose: Parse the XML file for all blog posts, save all the retrieved data as an array in an indexed hash
#	Incoming parameters: None
#	Returns: %posts - %hash = ($date => [ '$value1', '$value2', '$value3' ],...)
#	Dependencies: XML::LibXML, XML::LibXML::XPathContext
#
#------------------------------------

sub collectPosts {
	my %posts;
	
	# Loop through all the blog entries in the XML file and collect them if they meet certain parameters
	foreach my $post ($xc->findnodes('//post:entry')) {
		my $type = $xc->findvalue('./post:category/@term', $post);
		my $checkyear = getYear($xc->findvalue('./post:published', $post));
		
		if (($type =~ /post/) && ($checkyear eq $config{input}{year})) {
		
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


#------------------------------------
#
#	Sub name: combineSortClean
#	Purpose: Sort the posts, clean up all text, connect comments with posts
#	Incoming parameters: None
#	Returns: $output - cleaned, formatted, and tagged text
#
#------------------------------------

sub combineSortClean {
	my %comments = collectComments;
	my %posts = collectPosts;
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
		my @tags_array = split(/,/, $tags);
		
		
		#----------------------------------
		# Put extracted text into $output
		#----------------------------------
		
		$output .= "$ID{title}$title\n"; 		# Title
		$output .= "$ID{date}$date\n"; 		# Date
		$output .= "$ID{url}$posturl\n"; 		# URL
		
		# Custom character styles wrapped around specific authors 
		my $name = "";
		if ($author =~ /andrew/i) {
			$name = $ID{andrew};
		} elsif ($author =~ /nancy/i) {
			$name = $ID{nancy};
		} elsif ($author =~ /rachel/i) {
			$name = $ID{rachel};
		}
		
		foreach my $tag (@tags_array) {
			$output .= $ID{indexstart} . $ID{indexentrytype} . $ID{indexrangetype} . $ID{indexdisplay} . trim($tag) . $ID{indexend};
		}
		
		# $output .= "$ID{tags}$tags\n";		# Tags
		
		$content = makeParagraphs($content);
		$output .= "$ID{first}$content\n";	# Content with ID First paragraph style
		$output .= "$ID{author}$name-$author$ID{charend}\n"; 	# Author
		
		#-----------------------------------------
		# Add corresponding comments to the post
		#-----------------------------------------
		
		my $comments = '';
	
		foreach my $c (@{$comments{$posturl}}) {
			my @process_comment = split(/~~~/, $c);
			my $commentDate = $process_comment[0];
			my $commentAuthor = $process_comment[1];
			my $commentBody = $process_comment[2];
			$comments .= "$ID{commentauthor}$commentAuthor\n";	# Comment author
			$comments .= "$ID{commentdate}$commentDate\n";		# Comment date
			$comments .= "$ID{commentpara}$commentBody\n";		# Comment text
		}

		# If there are comments print them out
		if ($comments ne '') {
			$output .= "$ID{commentheader}Comments\n";
			$output .= makeParagraphs($comments, "comment");
		}

	}
	
	
	#---------------------------------------
	# Add file header and clean up $output
	#---------------------------------------
	
	$output = $config{output}{file_header}. "\n" . cleanText($output);
	
	return $output;
}

__END__

=head1 NAME

Blogger XML to InDesign

=head1 SYNOPSIS



=head1 DESCRIPTION

This script takes a backed-up Atom feed of a Blogger blog and converts it to a typographically clean InDesign Tagged Text file.

=head1 LICENSE

I<Blogger XML to InDesign is licensed under the terms of the MIT License reproduced below>

Copyright (c) 2009 Andrew Heiss

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=head1 AUTHOR

Andrew Heiss (andrew@andrewheiss.com)

=head1 DOCUMENTATION

=head2 Dependent Packages

L<Date::Format|Date::Format>, L<Date::Parse|Date::Parse>, L<XML::LibXML|XML::LibXML>, L<XML::LibXML::XPathContext|XML::LibXML::XPathContext>, L<HTML::Entities|HTML::Entities>, L<Config::General|Config::General>
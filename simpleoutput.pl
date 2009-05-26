#!/usr/bin/perl -w
use strict;
use XML::Simple;
use Data::Dumper;
print Dumper (XML::Simple->new()->XMLin());

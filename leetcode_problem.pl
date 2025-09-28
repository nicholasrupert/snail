#!/usr/bin/perl

# this is my leetcode problem for now
# you get two lists, containing the same elements in different orders
# you must take the first "n" elements of the first list
# and output them in the order in which they appear in the second list
# that's it for now!

use strict;
use warnings;

my @errors;

# the two inputs are @priority_array and @left_to_right array, but
# if you want them in a linked list instead, you can have that for free
# if you want them in a hash that maps one to the other, or a hash that maps from name
# to their index number in @priority_array or @left_to_right array, you have to build that.

my @priority_array = (
	"lamp",
	"dog",
	"wine",
	"table",
	"Led Zeppelin",
	"7 lakes",
	"whale",
	"37",
	"idea",
	"childlike sense of wonder",
	"lichen",
	"rhombus",
	"pulneni chushki",
	"Homer Simpson",
	"Rila"
);
	
	
my %left_to_right_array = (
	"lamp",
	"Homer Simpson",
	"pulneni chushki",
	"table",
	"rhombus",
	"whale",
	"Led Zeppelin",
	"Rila",
	"lichen",
	"37",
	"idea",
	"wine",
	"childlike sense of wonder",
	"7 lakes",
	"dog"
);




my @output_array = ("");

sub generateOutputArray { 
	# takes number of elements of @priority_array to display as an argument. Saved as $n.
	# Perl does not like arrays as arguments, so just use the two input arrays as global variables for now.
	
	my $n = $_[0];
	
	
	
	
	return @output_array;
}

generateOutputArray(5);

print ("Priority array:\n");
foreach (@priority_array) {
	print ("$_\n");
}
print ("____________________________\n");
print ("Left-to-right array:\n");
foreach (@left_to_right_array) {
	print ("$_\n");
}
print ("____________________________\n");
print ("Output array:\n");
foreach (@output_array) {
	print ("$_\n");
}
print ("Tada\n");

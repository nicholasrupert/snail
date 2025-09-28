#!/usr/bin/perl

# this is my leetcode problem for now
# you get two lists, containing the same elements in different orders
# no elements repeat.
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
	"Rila",
	"lamp"
);
	
	
my @left_to_right_array = (
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



my @output_array;


sub generateOutputArray { 
	# takes number of elements of @priority_array to display as an argument. Saved as $n.
	# Perl does not like arrays as arguments, so just use the two input arrays as global variables for now.
	
	my $n = $_[0];
		
	# Nick Rupert likes linked lists, and I can just make the inputs be this, so this does not count toward my O
	# this code breaks if the lists are empty, but I do not care about that.
	my %left_to_right_linked_list = ( 
		"head" => $left_to_right_array[0],
		$left_to_right_array[0] => "tail"
	);
	for (my $i=1; $i<@left_to_right_array; $i++) {
		$left_to_right_linked_list {$left_to_right_array[$i]} = "tail";
		$left_to_right_linked_list {$left_to_right_array[$i-1]} = $left_to_right_array[$i];;
	}
	
	
	# ok I have the input data structures I like now, so actually do it now
	# only the code below counts toward my O
	
	
	#unfortunately it is easier for me to generate the output list in reverse order
			
	my %right_to_left_merged_linked_list = (  # code breaks if empty list, who cares
		"head" => $priority_array[0],
		$priority_array[0] => "tail" 
	);
	
	for (my $i=1; $i<$n; $i++) {
		# if it the current item in priority array is at end of ltr list, then it must be all the way to the right
		# so it is first in rtl_list
		# if the current item in priority array is not at end of ltr list, then run through the rest of ltr list
		# starting at the current item in priority array. The first thing we hit in ltr list that is in previous
		# items in priority_array is the thing immediately to the right of our current item. 
		# Also, the thing we hit must already be in the rtl merged list, because its priority is earlier in priority array. 
		# Therefore, we can insert our current item after the thing we hit on in the rtl list. 
		
		my $window = $left_to_right_linked_list{$priority_array[$i]};
		my $loop_exit_flag = 0;
		my $match_found=-1;
		while ( $window ne "tail" and $loop_exit_flag == 0) {
			for (my $j=0; $j < $i and $loop_exit_flag == 0; $j++) {
				if  ( $priority_array[$j] eq $window ) {
					$match_found=$j;
					$loop_exit_flag=1;
				}
			}
			$window = $left_to_right_linked_list{$window};
		}
		if ($match_found == -1) {
			$right_to_left_merged_linked_list {$priority_array[$i]} = $right_to_left_merged_linked_list {"head"};
			$right_to_left_merged_linked_list {"head"} = $priority_array[$i];
		} else {
			$right_to_left_merged_linked_list {$priority_array[$i]} = $right_to_left_merged_linked_list {$priority_array[$match_found]};
			$right_to_left_merged_linked_list {$priority_array[$match_found]} = $priority_array[$i];
		}
	
	}
	
	# ok our earlier code generated the output list in reverse order, so flip it and convert it to an array
	
	
	
	@output_array = "" x $n;
	my $current_rtl_element = "head";
	my $k = $n-1;

	while ($right_to_left_merged_linked_list{$current_rtl_element} ne "tail" ) {
		$output_array[$k] = $right_to_left_merged_linked_list{$current_rtl_element};
		$current_rtl_element=$right_to_left_merged_linked_list{$current_rtl_element};
		$k--;
	}
	
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

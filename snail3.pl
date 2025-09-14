#!/usr/bin/perl

use strict;
use warnings;
my @errors;

# Perl note: backticks use /bin/sh
# /bin/sh is just a shortcut for ksh, bash or whatever

#################################################
#	Get all of the relevant system settings		#
#################################################

# check what shell we're using
# I don't actually think this makes a difference

my $ACCEPTABLE_SHELLS = "bash|ksh|csh";
my $shell;
($shell)=(`echo \$SHELL`=~/($ACCEPTABLE_SHELLS)/);
unless ($shell=~/$ACCEPTABLE_SHELLS/) {
	push (@errors,  "Error: shell $shell not recognized\n");
	exit (1);
}
print ("Shell: $shell\n");

# get operating system
# determines which shell commands we got

my $ACCEPTABLE_OS = "OpenBSD|Linux";
my $os;
($os)=(`uname -a`=~/($ACCEPTABLE_OS)/);
unless ($os=~/$ACCEPTABLE_OS/) {
	print ("Error: operating system $os not recognized\n");
	exit (0);
}
print ("OS: $os\n");

# get terminal emulator
# probably going to have to do better than this lol

my $terminal="alacritty";

#get sound mixer

my @ACCEPTABLE_SOUND_MIXERS=("amixer", "sndioctl");
my $sound_mixer;

if ($os eq "OpenBSD") {
	($sound_mixer)=(`whereis sndioctl`=~/(sndioctl)/);
	unless ($sound_mixer eq "sndioctl") {
		print ("Error: sound mixer not found\n");
		exit (0);
	}
}

print ("Sound mixer: $sound_mixer\n");

#get VPN type

my @ACCEPTABLE_VPNS=("mullvad", "wg");
my $vpn;

foreach (@ACCEPTABLE_VPNS) {
	($vpn)=(`whereis $_`=~/($_)/);
	if ($vpn eq $_) {
		last;
	}
}
unless (grep { $vpn eq $_ } @ACCEPTABLE_VPNS) {
	print ("Error: vpn $vpn not recognized\n");
	exit (0);
}
print ("VPN: $vpn\n");

# get config file

my $HOME=`echo \$HOME`;
chomp($HOME);
my @ACCEPTABLE_CONFIG_FILES=("$HOME/.snailrc", "$HOME/.config/snailrc", "/etc/snailrc", "./.snailrc");
my $config_file="DEFAULTS";

foreach (@ACCEPTABLE_CONFIG_FILES) {
	if (-e $_) {
		$config_file=$_;
		last;
	}
}
print("Config file: $config_file\n");

#################################################
#	Read and parse the config file					#
#################################################

my @applets_priority_array; # order applets appear/disappear with size changes
my %small_applets; # just little color blobs in right or left side
my %settings; 
my %colors;
my @small_applets;
my %displayed_applets_ltr_list;

my $SMALL_DIVIDER=" ";
my $BIG_DIVIDER=" | ";

my %applets_rtl_list = (
	"head" => "tail"
); #it's a linked list


my @ACCEPTABLE_APPLETS=(
	"time",
	"date",
	"battery_ac",
	"fan_speed",
	"cpu_temp",
	"wifi",
	"vpn",
	"volume",
	"small_applets"
);

my @ACCEPTABLE_SMALL_APPLETS=(
	"battery_ac_small",
	"mute_small",
	"cpu_temp_small",
	"wifi_small",
	"vpn_small",
	"volume_small"
);

my @ACCEPTABLE_SETTINGS=(
	"poll_delay",
	"date_format",
	"time_format",
	"small_applets"
);

my @ACCEPTABLE_COLOR_CLASSES=(
	"LABEL",
	"NUMBER",
	"VOLUME",
	"MUTE",
	"TIME",
	"COLON",
	"UNITS",
	"DATE",
	"DATE_DIVIDER",
	"DIVIDER",
	"BAD",
	"GOOD",
	"VERY_BAD",
	"NORMAL",
	"BLINK_1",
	"BLINK_2",
);

my @ACCEPTABLE_COLOR_NAMES= (
	"BLACK",
	"RED",
	"GREEN",
	"YELLOW",
	"BLUE",
	"MAGENTA",
	"CYAN",
	"LIGHT_GREY",
	"GREY",
	"LIGHT_RED",
	"LIGHT_GREEN",
	"LIGHT_YELLOW",
	"LIGHT_BLUE",
	"LIGHT_MAGENTA",
	"LIGHT_CYAN",
	"WHITE",
	"BLINK"
);

# default settings and flags so that we can be sure they all get set

%settings = (
	"poll_delay" => ".5",
	"small_applets" => "1",
	"date_format" => "\%Y-\%m-\%d",
	"time_format" => "\%H:\%M",
	"alignment" => "right"
);


# hard coded ascii values for basic color names
# the ascii values are hard coded because the alacritty theme or
# whatever will change the hex values of these ascii values anyway

my %ASCII_COLORS = (
	"BLACK" => "\e[1;30m",
	"RED" => "\e[1;31m",
	"GREEN" => "\e[1;32m",
	"YELLOW" => "\e[1;33m",
	"BLUE" => "\e[1;34m",
	"MAGENTA" => "\e[1;35m",
	"CYAN" => "\e[1;36m",
	"LIGHT_GREY" => "\e[1;37m",
	"GREY" => "\e[1;90m",
	"LIGHT_RED" => "\e[1;91m",
	"LIGHT_GREEN" => "\e[1;92m",
	"LIGHT_YELLOW" => "\e[1;93m",
	"LIGHT_BLUE" => "\e[1;94m",
	"LIGHT_MAGENTA" => "\e[1;95m",
	"LIGHT_CYAN" => "\e[1;96m",
	"WHITE" => "\e[1;97m"
);

# default colors get set here so that we can be sure all get set

%colors = (
	"LABEL" => $ASCII_COLORS{"LIGHT_GREY"},
	"NUMBER" => $ASCII_COLORS{"LIGHT_CYAN"},
	"VOLUME" => $ASCII_COLORS{"LIGHT_CYAN"},
	"MUTE" => $ASCII_COLORS{"GREEN"},
	"TIME" => $ASCII_COLORS{"YELLOW"},
	"COLON" => $ASCII_COLORS{"LIGHT_GREY"},
	"UNITS" => $ASCII_COLORS{"GREY"},
	"DATE" => $ASCII_COLORS{"CYAN"},
	"DATE_DIVIDER" => $ASCII_COLORS{"GREY"},
	"DIVIDER" => $ASCII_COLORS{"LIGHT_BLUE"},
	"BAD" => $ASCII_COLORS{"LIGHT_RED"},
	"GOOD" => $ASCII_COLORS{"GREEN"},
	"NORMAL" => $ASCII_COLORS{"LIGHT_GREY"},
	"BLINK_1" => $ASCII_COLORS{"RED"},
	"BLINK_2" => $ASCII_COLORS{"YELLOW"},
	"VERY_BAD" => "BLINK" # its special
);

my $number_of_small_applets=0;
my $date_and_time_adjacent=0;
my $SMALL_APPLETS_WIDTH=1;
my $DIVIDER_WIDTH=3; # space|space

# now read the config file, check inputs for sanity, and set the configs

unless ($config_file eq "DEFAULTS") {
	open (my $config_readline, '<', $config_file);
	print ("\n");
	my $nextline;
	my $priority_index=0;
	my $small_applets_index=0;
	my $previous_applet="head";
	for (my $i=0; <$config_readline>; $i++) {
		# anticomment character for rtl order is ^
		if ($_=~/^\^(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				print ("Error: applet $1 in RTL order not recognized\n");
				exit (0);
			}
			$applets_rtl_list{$1} = $applets_rtl_list{$previous_applet};
			$applets_rtl_list{$previous_applet} = $1;
			$previous_applet = $1;
		} 
		# anticomment character for appearance/disappearance priority is &
		elsif ($_=~/^&(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				print ("Error: applet $1 in priority order not recognized\n");
				exit (0);
			}
			$applets_priority_array[$priority_index]=$1;
#			$applets_priority_hash{$1}=$priority_index;
			print("Priority index $priority_index: $applets_priority_array[$priority_index]\n");
			$priority_index++;
		} 
		# anticomment character for small applets order is *
		elsif ($_=~/^\*(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_SMALL_APPLETS) {
				print ("Error: small applet $1 not recognized\n");
				exit (0);
			}
			$small_applets[$small_applets_index]=$1;
			print("Small applets index $small_applets_index: $small_applets[$small_applets_index]\n");
			$small_applets_index++;
		}

		# anticomment character for special settings is !
		# form is %setting=number
		elsif ($_=~/^!(.*)=/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_SETTINGS) {
				print ("Error: special setting $1 not recognized\n");
				exit (0);
			}
			my $k=$1;
			($settings{$1})=($_=~/=(.*)/);
			print ("Special setting $k set: $settings{$1}\n");
		}
		# anticomment character for color settings is $
		# form is $COLOR_CLASS_NAME=COLOR_NAME
		elsif ($_=~/^\$(.*)=/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_COLOR_CLASSES) {
				print ("Error: color class $1 not recognized\n");
				exit (0);
			}
			my $k=$1;
			($colors{$1})=($_=~/=(.*)/);
			unless (grep { $colors{$1} eq $_ } @ACCEPTABLE_COLOR_NAMES) {
				print ("Error: color name $1 not recognized\n");
				exit (0);
			}
			print ("Color class $k set: $colors{$1}\n");
		}
		# no else here, because everything else is ignored
		
		$number_of_small_applets=$small_applets_index;
	}
} else {  # default settings
	%applets_rtl_list = ( # check this against the array before changing
		"head"=>"small_applets",
		"small_applets"=>"time",
		"time" => "date",
		"date" => "battery_ac",
		"battery_ac" => "fan_speed",
		"fan_speed" => "cpu_temp",
		"cpu_temp" => "wifi",
		"wifi" => "vpn",
		"vpn" => "volume",
		"volume" => "tail"		
	);
#	$number_of_small_applets=0;
#	$date_and_time_adjacent=1;
	# default special, flag, and color settings already set
	print ("Using defaults. No config file opened.\n");
}

# check that all applets in priority listing are in RTL listing


foreach (@applets_priority_array) {
	unless (exists $applets_rtl_list{$_}) {
		print ("Error: applet $_ appears in priority list but not in RTL list\n");
		exit (0);
	}
}
print ("All applets in priority list appear in RTL list.\n");

#################################################
#	Figure out how big the window is and which	#
#	applets to display and display them				#
#################################################

#redo max widths to change depending on settings
# e.g. if they wanted a shorter or longer date format

my %APPLETS_MAX_WIDTHS = (		# all small applets have width 1			
	"time" => "5",					# 23:59
	"date" => "10",					# 2025-12-31
	"battery_ac" => "7",			# bat 39% 
	"fan_speed" => "7",				# who knows maybe fan 100
	"cpu_temp" => "9",				# CPU 100*C
	"wifi" => "9",					# wifi up / wifi down
	"vpn" => "8",						# vpn bg / vpn down	
	"volume" => "11",					# audio muted / audio 123%
	"small_applets" => $number_of_small_applets
);

print ("applets max width: ".$APPLETS_MAX_WIDTHS{"time"}."\n");



%displayed_applets_ltr_list = ( # THIS IS LEFT TO RIGHT
	"head" => "tail"
); #this is a linked list lmao I heard my CS friends mention them

#structure looks like this:
# "first" => first_applet_name,
# first_applet_name => second_applet_name,
# second_applet_name => last_applet_name
# last_applet_name => "last"

sub addApplet { #arg is priority index
	my $applet_to_add=$applets_priority_array[$_[0]];
	print ("Applet to add: $applet_to_add\n");
	my $applet_to_left=$applets_rtl_list{$applet_to_add};
	my $applet_two_to_left=$applets_rtl_list{$applet_to_left};
 	if ( $_[0] == 0 ) {
		$displayed_applets_ltr_list{"head"}=$applet_to_add;
		$displayed_applets_ltr_list{$applet_to_add}="tail";
	} else {
		my $i=0;
		while ($i<50 and $applet_to_left ne "tail" and
			not exists $displayed_applets_ltr_list{$applet_to_left} ) {
			$applet_to_left=$applet_two_to_left;
			$applet_two_to_left=$applets_rtl_list{$applet_to_left};
			$i++; #just to avoid infinite loops
		}
		if ($applet_to_left eq "tail") {
			$displayed_applets_ltr_list{$applet_to_add}=$displayed_applets_ltr_list{"head"};
			$displayed_applets_ltr_list{"head"}=$applet_to_add;
		} else {
			$displayed_applets_ltr_list{$applet_to_add}=$displayed_applets_ltr_list{$applet_to_left};
			$displayed_applets_ltr_list{$applet_to_left}=$applet_to_add;
		}
	}	
}	

for (my $i=0; $i<5; $i++) {
	addApplet($i);
}

# for debugging:
my $s="head";
while ($displayed_applets_ltr_list{$s} ne "tail") {
	print ("$displayed_applets_ltr_list{$s} ");
	$s=$displayed_applets_ltr_list{$s};
}
print ("\n");

my @displayed_applets_with_dividers;
#structure will looks like this:
# [0] small_applets
# [1] [space]|[space]
# [2] time
# [3] [space]
# [4] date
# [5] [space]|[space]
# [6] vpn
# [7] [space]|[space]
# [8] volume

sub addDividers {
	my $current_applet=$displayed_applets_ltr_list{"head"};
	print ("current applet: $current_applet\n");
	my $next_applet=$displayed_applets_ltr_list{$current_applet};
	my $i=0;
	my $k=0; # this one is for preventing infinite loops
	
	while ($current_applet ne "tail" and $k<50) {
		$displayed_applets_with_dividers[$i] = $current_applet;
		$i++;
		if ($next_applet ne "tail") {
			if (($current_applet eq "date" or $current_applet eq "time" or $current_applet eq "small_applets")
				and ($next_applet eq "date" or $next_applet eq "time" or $next_applet eq "small_applets")) {
				$displayed_applets_with_dividers[$i]=$SMALL_DIVIDER;
				$current_applet=$displayed_applets_ltr_list{$current_applet};
				$next_applet=$displayed_applets_ltr_list{$current_applet};
			} else {
				$displayed_applets_with_dividers[$i]=$BIG_DIVIDER;
				$current_applet=$displayed_applets_ltr_list{$current_applet};
				$next_applet=$displayed_applets_ltr_list{$current_applet};
			}
			$i++;
		} else {
			$current_applet="tail";
		}
		$k++;
	}
}


addDividers();

for (my $i=0; $i<@displayed_applets_with_dividers; $i++) {
	print ($displayed_applets_with_dividers[$i]);
}
print ("\n");

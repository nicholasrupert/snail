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

my @applets_rtl_array;   #stores applets in rtl order
my @applets_priority_array; # order applets appear/disappear with size changes
my %applets_rtl_hash;	# inverse of applets_rtl_array
my %applets_priority_hash; #inverse of applets_priority_array
my @small_applets; # just little color blobs in right or left side
my %settings; 
my %colors;

my @ACCEPTABLE_APPLETS=(
	"time",
	"date",
	"battery_ac",
	"fan_speed",
	"cpu_temp",
	"wifi",
	"vpn",
	"volume"
);

my @ACCEPTABLE_SMALL_APPLETS=(
	"battery_ac_small",
	"mute_small",
	"cpu_temp_small",
	"wifi_small",
	"vpn_small"
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
	my $rtl_index=0;
	my $priority_index=0;
	my $small_applets_index=0;
	for (my $i=0; <$config_readline>; $i++) {
		# anticomment character for rtl order is ^
		if ($_=~/^\^(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				print ("Error: applet $1 in RTL order not recognized\n");
				exit (0);
			}
			$applets_rtl_array[$rtl_index]=$1;
			$applets_rtl_hash{$1}=$rtl_index;
			print("RTL $rtl_index: $applets_rtl_array[$rtl_index]\n");
			
			# this bit checks for whether time and date are next
			# to each other because they have a special divider
			if (($applets_rtl_array[$i] eq "time" and $applets_rtl_array[$i-1] eq "date")
				|| ($applets_rtl_array[$i] eq "date" and $applets_rtl_array[$i-1] eq "time")) {
				$date_and_time_adjacent=1;
			}
			$rtl_index++;
		} 
		# anticomment character for appearance/disappearance priority is &
		elsif ($_=~/^&(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				print ("Error: applet $1 in priority order not recognized\n");
				exit (0);
			}
			$applets_priority_array[$priority_index]=$1;
			$applets_priority_hash{$1}=$priority_index;
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
	@applets_rtl_array = (
		"small_applets",
		"time",
		"date",
		"battery_ac",
		"fan_speed",
		"cpu_temp",
		"wifi",
		"vpn",
		"volume"		
	);
	%applets_rtl_hash = ( # check this against the array before changing
		"small_applets" => 0,
		"time" => 1,
		"date" => 2,
		"battery_ac" => 3,
		"fan_speed" => 4,
		"cpu_temp" => 5,
		"wifi" => 6,
		"vpn" => 7,
		"volume" => 8		
	);
	@applets_priority_array = (
		"small_applets",
		"time",
		"date",
		"battery_ac",
		"volume",
		"vpn",
		"wifi",
		"cpu_temp",
		"fan_speed"
	);
	%applets_priority_hash = ( # check this against the array before changing
		"small_applets" => 0,
		"time" => 1,
		"date" => 2,
		"battery_ac" => 3,
		"volume" => 4,
		"vpn" => 5,
		"wifi" => 6,
		"cpu_temp" => 7,
		"fan_speed" => 8
	);
	$number_of_small_applets=0;
	$date_and_time_adjacent=1;
	# default special, flag, and color settings already set
}

# check that all applets in priority listing are in RTL listing
foreach (@applets_priority) {
	my $current_applet=$_;
	unless (	grep { $current_applet eq $_ } @applets_rtl) {
		print ("Error: applet $current_applet appears in priority list but not in RTL list\n");
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
	"battery_ac" => "7",			# ac 39% / bat 39% 
	"fan_speed" => "7",				# who knows maybe fan 100
	"cpu_temp" => "9",				# CPU 100*C
	"wifi" => "9",					# wifi up / wifi down
	"vpn" => "8",						# vpn bg / vpn down	
	"volume" => "11"					# audio muted / audio 123%
);

print ("applets max width: ".$APPLETS_MAX_WIDTHS{"time"}."\n");


sub showApplets {
	# reads the terminal size
	# figures out which applets in the priority list will fit with dividers
	# which requires simultaneously checking rtl order to decide
	# which divider will be displayed. this is hard to figure out for me
	# idk about you
	
	my $TERMINAL_WIDTH=`tput cols`;
	
	# only do stuff if the column width is -1 (to force) or changed
	
	if ($TERMINAL_WIDTH == $_ && $_!=-1) {
		return ();
	}		
	
	print ("Terminal width: $TERMINAL_WIDTH");
	my $displayed_applets_max_width=0;
	
	# I suspect for the display we don't need a priority array/hash, just rtl
	my @displayed_applets_priority_array; 
	my @displayed_applets_rtl_array;
	my %displayed_applets_priority_hash; #inverse of the array
	my %displayed_apprets_rtl_hash; # inverse of the array
	my $leading_spaces=0; # this will format everything later bc we will remove applets to fit, 
									but the applets aren't width 1
		
	my $DIVIDER = " | "; # could be worth letting the user set this idk
	my $SMALL_DIVIDER = " ";

	# this gets the total length of applets (each at max width)
	# that would fit in the terminal
	
	$number_of_small_applets=@small_applets;
	
	my $priority_index=0;
	my $rtl_index=0;
		
	foreach (@applets_priority_array) {
		# if it's the first applet in priority, no divider check needed.
		# each time we 
		if ($priority_index==0) {
			if ($_ eq "small_applets") {
				$displayed_applets_max_width = $number_of_small_applets;
			} else {
				$displayed_applets_max_width = $APPLETS_MAX_WIDTHS{$_};
			}
			# using less than instead of <= leaves a space for cursor
			if ($displayed_applets_max_width < $TERMINAL_WIDTH) {
				$displayed_applets_priority_array[0]=$_;
				$displayed_applets_ltr_array[$applets_ltr_hash{$_}]=$_;
				$displayed_applets_priority_hash{$_}=0;
				$displayed_applets_ltr_hash{$_}=$applets_ltr_hash{$_};
			}	else { 
				# we're not displaying small_applets one at a time
				#because it would be hard to tell which one you're seeing
				$displayed_applets_priority_array[0]="too_small";
				$displayed_applets_ltr_array[$applets_ltr_hash{$_}]="too_small";
				$displayed_applets_priority_hash{$_}=0;
				$applets_ltr_hash{$_}="too small";
				last;
			}
		} else { # ok so we're NOT on the first thingy displayed
			if ($_ eq "small_applets") {
				$displayed_applets_max_width += $number_of_small_applets;
			} else {
				$displayed_applets_max_width += $APPLETS_MAX_WIDTHS{$_};
			}
			# figure out divider width. is time next to date?
			if ($_ eq "date") {
				# oof, inserting a new applet could add a short divider
				# on either side. 
				# need to check whether the nonempty 
				# ok you got this. just check ltr indices between them?
				unless ($applets_ltr_hash{"time"}==undef) {
					for (my $k=lesser($applets_ltr_hash{"time"},$applets_ltr_hash{"date"}); $k<=greater($applets_ltr_hash{"time"},$applets_ltr_hash{"date"})
			}
		if ($priority_index>0) {
		 and $applets_ltr_hash{$_} 
		}
	
}


# i am fully aware of max and min, but
# it would be neat not to include any modules at all
# also, I do not give a fuck about if the two
# numbers are equal.
	
sub lesser {
	if ($_[0] < $_[1]) {
		return ($_[0]);
	} else {
		return ($_[1]);
	}
}

sub greater {
	if ($_[0] > $_[1]) {
		return ($_[0]);
	} else {
		return ($_[1]);
	}
}

showApplets();

#while(1) {
#	sleep($settings{"poll_delay"});
#	showApplets();
#}



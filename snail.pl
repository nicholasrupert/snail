#!/usr/bin/perl

use strict;

# Perl note: backticks use /bin/sh
# /bin/sh is just a shortcut for ksh, bash or whatever

# check what shell we're using
# I don't actually think this makes a difference

my $ACCEPTABLE_SHELLS = "bash|ksh|csh";
my $shell;
($shell)=(`echo \$SHELL`=~/($ACCEPTABLE_SHELLS)/);
unless ($shell=~/$ACCEPTABLE_SHELLS/) {
	print ("Error: shell $shell not recognized\n");
	exit (0);
}
print ("Shell: $shell\n");

# get operating system
# determines which shell commands we got

my $ACCEPTABLE_OS = "OpenBSD|Linux";
my $os;
($os)=(`uname -a`=~/($ACCEPTABLE_OS)/);
unless ($os=~/$ACCEPTABLE_OS/) {
	print ("Error: shell $os not recognized\n");
	exit (0);
}
print ("OS: $os\n");

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

# get configuration

my @applets_rtl;
my @applets_priority;
my %flags;
my %settings;
my %colors;

my @ACCEPTABLE_APPLETS=(
	"battery_ac_small",
	"volume_small",
	"wifi_small",
	"vpn_small",
	"time",
	"date",
	"battery_ac",
	"fan_speed",
	"cpu_temp",
	"wifi",
	"vpn",
	"volume"
);

my @ACCEPTABLE_FLAGS=(
	"simultaneous_big_small_applets",
	"small_applets_all_same_priority",
);

my @ACCEPTABLE_SETTINGS=(
	"poll_delay"
);

my @ACCEPTABLE_COLOR_CLASSES=(
	"LABEL",
	"NUMBER",
	"VOLUME",
	"MUTE",
	"TIME",
	"COLON",
	"SYMBOL",
	"DATE",
	"DATE_DIVIDER",
	"DIVIDER",
	"BAD",
	"GOOD",
	"NORMAL"
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
	"WHITE"
);

# hard coded ascii values for basic color names
# the ascii values are hard coded because the alacritty theme or
# whatever will change the hex values of these ascii values anyway

my %ASCII_COLORS= {
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
};
# default colors get set here so that we can be sure all get set

%colors = {  # I think this is wrong, should be names in quotes
	"LABEL" => $ASCII_COLORS{"LIGHT_GREY"},
	"NUMBER" => $ASCII_COLORS{"LIGHT_CYAN"},
	"VOLUME" => $ASCII_COLORS{"LIGHT_CYAN"},
	"MUTE" => $ASCII_COLORS{"GREEN"},
	"TIME" => $ASCII_COLORS{"YELLOW"},
	"COLON" => $ASCII_COLORS{"LIGHT_GREY"},
	"SYMBOL" => $ASCII_COLORS{"GREY"},
	"DATE" => $ASCII_COLORS{"CYAN"},
	"DATE_DIVIDER" => $ASCII_COLORS{"GREY"},
	"DIVIDER" => $ASCII_COLORS{"LIGHT_BLUE"},
	"BAD" => $ASCII_COLORS{"LIGHT_RED"},
	"GOOD" => $ASCII_COLORS{"GREEN"},
	"NORMAL" => $ASCII_COLORS{"LIGHT_GREY"} 
};

# now read the config file, check inputs for sanity, and set the configs

unless ($config_file eq "DEFAULTS") {
	open (my $config_readline, '<', $config_file);
	print ("\n");
	my $nextline;
	my $rtl_index=0;
	my $priority_index=0;
	for (my $i=0; <$config_readline>; $i++) {
		# anticomment character for rtl order is ^
		if ($_=~/^\^(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				print ("Error: applet $1 in RTL order not recognized\n");
				exit (0);
			}
			$applets_rtl[$rtl_index]=$1;
			print("RTL $rtl_index: $applets_rtl[$rtl_index]\n");
			$rtl_index++;
		} 
		# anticomment character for appearance/disappearance priority is &
		elsif ($_=~/^&(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				print ("Error: applet $1 in priority order not recognized\n");
				exit (0);
			}
			$applets_priority[$priority_index]=$1;
			print("Priority index $priority_index: $applets_priority[$priority_index]\n");
			$priority_index++;
		} 
		# anticomment character for flags is !
		elsif ($_=~/^!(.*)/) { 
			unless (grep { $1 eq $_ } @ACCEPTABLE_FLAGS) {
				print ("Error: special flag $1 not recognized\n");
				exit (0);
			}
			$flags{$1}=1;
			print ("Flag $1 set: $flags{$1}\n");
		}
		# anticomment character for special settings is %
		# form is %setting=number
		elsif ($_=~/^%(.*)=/) {
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
	}
} else {  # default settings
	@applets_rtl = (
		"battery_ac_small",
		"volume_small",
		"wifi_small",
		"vpn_small",
		"time",
		"date",
		"battery_ac",
		"fan_speed",
		"cpu_temp",
		"wifi",
		"vpn",
		"volume"		
	);
	@applets_priority = (
		"battery_ac_small",
		"volume_small",
		"wifi_small",
		"vpn_small",
		"time",
		"date",
		"battery_ac",
		"volume",
		"vpn",
		"wifi",
		"cpu_temp",
		"fan_speed"
	);
	%flags = {
		"small_applets_all_same_priority"=>1,
		"simultaneous_big_small_applets"=>1
	};
	%settings {
		"poll_delay"=>.5
	};
	# default color settings already set
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



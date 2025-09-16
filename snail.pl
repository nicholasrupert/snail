#!/usr/bin/env perl

use strict;
use warnings;

#use Term::ReadKey;

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
	die ( "Error: shell $shell not recognized\n");
}
#print ("Shell: $shell\n");

# get operating system
# determines which shell commands we got

my $ACCEPTABLE_OS = "OpenBSD|Linux";
my $os;
($os)=(`uname -a`=~/($ACCEPTABLE_OS)/);
unless ($os=~/$ACCEPTABLE_OS/) {
	die ("Error: operating system $os not recognized\n");
}
#print ("OS: $os\n");

# get terminal emulator
# probably going to have to do better than this lol

my $terminal="alacritty";

#get sound mixer

my @ACCEPTABLE_SOUND_MIXERS=("amixer", "sndioctl");
my $sound_mixer;

if ($os eq "OpenBSD") {
	($sound_mixer)=(`whereis sndioctl`=~/(sndioctl)/);
	unless ($sound_mixer eq "sndioctl") {
		die ("Error: sound mixer not found\n");
	}
}

#print ("Sound mixer: $sound_mixer\n");

#get VPN type
# this check should really get moved to when we read the applet list
# because probably most people don't even use or care about vpn

my @ACCEPTABLE_VPNS=("mullvad", "wg");
my $vpn="NONE";

foreach (@ACCEPTABLE_VPNS) {
	my $whereis_output=`whereis $_`;
#	print ("in the vpn loop, on $whereis_output\n");
	if ($whereis_output=~/$_/) {
#		print ("in the if\n");
		($vpn)=($whereis_output=~/($_)/);
#		print ("VPN: $vpn matches $_\n");
		last;
	}
}
unless (grep { $vpn eq $_ } @ACCEPTABLE_VPNS or $vpn eq "NONE") {
	die ("Error: vpn $vpn not recognized\n");
}
#print ("VPN: $vpn\n");

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
#print("Config file: $config_file\n");

#################################################
#	Read and parse the config file					#
#################################################

my %settings; 
my %colors;

my $SMALL_DIVIDER=" ";
my $BIG_DIVIDER=" | ";


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
#	"small_applets",
	"wifi_interface",
	"indent",
	"cursor",
	"snail_position",
	"snail_logo",
	"alignment"
);

my @ACCEPTABLE_COLOR_CLASSES=(
	"LABEL",
	"NUMBER",
	"VOLUME",
	"MUTE",
	"TIME",
	"COLON",
	"DASH",
	"UNITS",
	"DATE",
	"SMALL_DIVIDER",
	"DIVIDER",
	"BAD",
	"GOOD",
	"WARN",
	"NORMAL",
	"BLINK_1",
	"BLINK_2",
	"BACKGROUND"
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
	"alignment" => "right",
	"wifi_interface" => "iwx0",
	"indent" => "1", #indent less than one totally fucks everything if right-aligned
	"cursor" => "left",
	"snail_position" => "left",
	"snail_logo" => "1"
);



# hard coded ANSI values for basic color names
# the ANSI values are hard coded because the alacritty theme or
# whatever will change the hex values of these ANSI values anyway

my %ANSI_COLORS = (
	"BLACK" => "\e[1;30;40m",
	"RED" => "\e[1;31;40m",
	"GREEN" => "\e[1;32;40m",
	"YELLOW" => "\e[1;33;40m",
	"BLUE" => "\e[1;34;40m",
	"MAGENTA" => "\e[1;35;40m",
	"CYAN" => "\e[1;36;40m",
	"LIGHT_GREY" => "\e[1;37;40m",
	"GREY" => "\e[1;90;40m",
	"LIGHT_RED" => "\e[1;91;40m",
	"LIGHT_GREEN" => "\e[1;92;40m",
	"LIGHT_YELLOW" => "\e[1;93;40m",
	"LIGHT_BLUE" => "\e[1;94;40m",
	"LIGHT_MAGENTA" => "\e[1;95;40m",
	"LIGHT_CYAN" => "\e[1;96;40m",
	"WHITE" => "\e[1;97;40m"
);

# default colors get set here so that we can be sure all get set

my %COLORS = (
	"LABEL" => $ANSI_COLORS{"LIGHT_GREY"},
	"NUMBER" => $ANSI_COLORS{"LIGHT_CYAN"},
	"VOLUME" => $ANSI_COLORS{"LIGHT_CYAN"},
	"MUTE" => $ANSI_COLORS{"GREEN"},
	"TIME" => $ANSI_COLORS{"YELLOW"},
	"COLON" => $ANSI_COLORS{"LIGHT_GREY"},
	"DASH" => $ANSI_COLORS{"LIGHT_GREY"},
	"UNITS" => $ANSI_COLORS{"LIGHT_GREY"},
	"DATE" => $ANSI_COLORS{"CYAN"},
	"SMALL_DIVIDER" => $ANSI_COLORS{"GREY"},
	"DIVIDER" => $ANSI_COLORS{"LIGHT_BLUE"},
	"BAD" => $ANSI_COLORS{"LIGHT_RED"},
	"GOOD" => $ANSI_COLORS{"GREEN"},
	"NORMAL" => $ANSI_COLORS{"LIGHT_GREY"},
	"BLINK_1" => $ANSI_COLORS{"RED"},
	"BLINK_2" => $ANSI_COLORS{"YELLOW"},
	"VERY_BAD" => "BLINK", # its special
	"BACKGROUND" => $ANSI_COLORS{"BLACK"}
);

my %APPLETS_MAX_WIDTHS = (		# all small applets have width 1			
	"time" => 5,					# 23:59
	"date" => 10,					# 2025-12-31
	"battery_ac" => 7,			# bat 39% 
	"fan_speed" => 13,				# fan 10000 rpm
	"cpu_temp" => 9,				# CPU 100*C
	"wifi" => 9,					# wifi up / wifi down
	"vpn" => 8,						# vpn bg / vpn down	
	"volume" => 11,					# audio muted / audio 123%
	"small_applets" => 0,
	"small_divider" => 1,
	"big_divider" => 3
);

my %DIVIDERS = (
	"small_divider" => " ",
	"big_divider" => " | "
);

my $number_of_small_applets=0;
my $SMALL_APPLETS_WIDTH=1;

my @priority_array;
my %RTL_list = ("head" => "tail");
my %display_LTR_list = ("head" => "tail");
my @display_divided_LTR_array;
my @small_applets;
my $PREVIOUS_DISPLAY_STRING_CF="init";
my $PREVIOUS_TERMINAL_HEIGHT=getTerminalHeight();
my $too_small_to_show_applets_flag=0;

# now read the config file, check inputs for sanity, and set the configs

unless ($config_file eq "DEFAULTS") {
	open (my $config_readline, '<', $config_file);
	#print ("\n");
	my $nextline;
	my $priority_index=0;
	my $small_applets_index=0;
	my $previous_applet="head";
	for (my $i=0; <$config_readline>; $i++) {
		# anticomment character for rtl order is ^
		chomp ($_);
		if ($_=~/^\^(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				die ("Error: applet $1 in RTL order not recognized\n");
			}
			#print ("RTL order: $1\n");
			$RTL_list{$1} = $RTL_list{$previous_applet};
			$RTL_list{$previous_applet} = $1;
			$previous_applet = $1;
		} 
		# anticomment character for appearance/disappearance priority is &
		elsif ($_=~/^&(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_APPLETS) {
				die ("Error: applet $1 in priority order not recognized\n");
			}
			$priority_array[$priority_index]=$1;
#			$applets_priority_hash{$1}=$priority_index;
			#print("Priority index $priority_index: $priority_array[$priority_index]\n");
			$priority_index++;
		} 
		# anticomment character for small applets order is *
		elsif ($_=~/^\*(.*)/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_SMALL_APPLETS) {
				die ("Error: small applet $1 not recognized\n");
			}
			$small_applets[$small_applets_index]=$1;
			#print("Small applets index $small_applets_index: $small_applets[$small_applets_index]\n");
			$small_applets_index++;
		}

		# anticomment character for special settings is !
		# form is !setting=number
		
		#kinda want to change this to % but not now
		elsif ($_=~/^!(.*)=/) {
			unless (grep { $1 eq $_ } @ACCEPTABLE_SETTINGS) {
				die ("Error: special setting $1 not recognized\n");
			}
			my $k=$1;
			($settings{$k})=($_=~/=(.*)/);
			#print ("Special setting $k set: $settings{$k}\n");
		}
		# anticomment character for color settings is $
		# form is $COLOR_CLASS_NAME=COLOR_NAME
		elsif ($_=~/^\$(.*)=/) {
			my $color_class="";
			my $color_name="";
			if (grep { $1 eq $_ } @ACCEPTABLE_COLOR_CLASSES) {
				$color_class = $1;
			} else {
				die ("Error: color class $1 not recognized\n");
			}			
			
			($color_name) = ($_=~/=(.*)/);
			if (grep { $color_name eq $_ } @ACCEPTABLE_COLOR_NAMES) {
				$COLORS{$color_class}=$ANSI_COLORS{$color_name};
				#print ("Color class $color_class set: $color_name\n");
			} else {
				die ("Error: color name $1 not recognized\n");
			}
		}
		# no else here, because everything else is ignored
		
		$number_of_small_applets=$small_applets_index;
		$APPLETS_MAX_WIDTHS{"small_applets"} = $number_of_small_applets;
	}
	close ($config_readline);
} else {  # default settings
	%RTL_list = ( # check this against the array before changing
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
	#print ("Using defaults. No config file opened.\n");
}

# check that all applets in priority listing are in RTL listing


foreach (@priority_array) {
	unless (exists $RTL_list{$_}) {
		die ("Error: applet $_ appears in priority list but not in RTL list\n");
	}
}
#print ("All applets in priority list appear in RTL list.\n");

#################################################
#	Figure out how big the window is and which	#
#	applets to display and display them				#
#################################################

#redo max widths to change depending on settings
# e.g. if they wanted a shorter or longer date format


sub addAppletLTR {
	# arg 1: priority index of applet to add
	
	my $index=$_[0];
	my $applet=$priority_array[$index];
	#print ("Adding $applet\n");
	my $window=$RTL_list{$applet};
	my $stopper=0;
	
	# runs through the RTL priority list, starting at the app to left
	# the first app that is present in the displayed list is the one
	# directly to the left of the app to add. so insert app to add directly
	# after it in the display LTR list.
	
	while ($window ne "tail" and $stopper < 50) {
		if (grep { $window eq $_ } %display_LTR_list) {
			$display_LTR_list{$applet}=$display_LTR_list{$window};
			$display_LTR_list{$window}=$applet;
			$stopper=100;
		}
		$window=$RTL_list{$window};				 
		$stopper++;
	}
	# if we didn't add it already, it must be first
	if ($stopper < 100) {	
		$display_LTR_list{$applet}=$display_LTR_list{"head"};
		$display_LTR_list{"head"}=$applet;
	}
}

sub getDisplayStringMaxWidth {
	my $width=0;
	for (my $i=0; $i<@display_divided_LTR_array and $display_divided_LTR_array[$i] ne "tail"; $i++) {
		$width+=$APPLETS_MAX_WIDTHS{$display_divided_LTR_array[$i]};
	}
	#print ("$width\n");
	return ($width);
}

sub addDividers {
	my $index = 0;
	my $window = $display_LTR_list{"head"};
	my $stopper = 0;
	while ($window ne "tail" and $stopper<50) {
		$display_divided_LTR_array[$index] = $window;
		$index++;
		
		if ($display_LTR_list{$window} eq "tail") {
			$display_divided_LTR_array[$index] = "tail";
			$stopper=100;
		} elsif (($window eq "date" or $window eq "time" or $window eq "small_applets") and
			($display_LTR_list{$window} eq "date" or $display_LTR_list{$window} eq "time" or
			$display_LTR_list{$window} eq "small_applets")) {
				$display_divided_LTR_array[$index]= "small_divider";
		} else { 
			$display_divided_LTR_array[$index] = "big_divider";
		}
		$window=$display_LTR_list{$window};
		$index++;
		$stopper++;
	}
}

sub eraseLTRLists {
	%display_LTR_list = ("head" => "tail");
	@display_divided_LTR_array = ("tail");
}

sub debugShit {

my $init="head";
for (my $i=0; $i<50; $i++) {
	#print ("Display LTR: $display_LTR_list{$init}\n");
	if ($display_LTR_list{$init} eq "tail") {
		last;
	} else {
		$init=$display_LTR_list{$init};
	}
}

for (my $i=0; $i<@display_divided_LTR_array and $display_divided_LTR_array[$i] ne "tail"; $i++) {
	#print ($display_divided_LTR_array[$i]);
	#print (" ");
}
#print ("\n");

getDisplayStringMaxWidth();
}

sub getTerminalWidth {
	return (`tput cols`);
}

sub getTerminalHeight {
	return (`tput lines`);
}

sub setAppletsMaxWidths {
	my $date_format=$settings{"date_format"};
	my $date_max_width = length (`date +$date_format`);
	$APPLETS_MAX_WIDTHS{"date"}=$date_max_width;
}

########################################
#													#
# actually get the displayed applets	#
#													#
########################################	

sub setAppletsToDisplay () {
	eraseLTRLists();
	my $MAX_WIDTH=getTerminalWidth()-2*$settings{"indent"};
	my $display_width=$settings{"indent"};
	my $applet_counter=0;
	while ($display_width<$MAX_WIDTH and $applet_counter<@priority_array and
		$applet_counter<50) {
			addAppletLTR($applet_counter);
			addDividers();
			$display_width=getDisplayStringMaxWidth()+$settings{"indent"};
			$applet_counter++;
	}
	if ($display_width > $MAX_WIDTH) {
		eraseLTRLists();
		for (my $i=0; $i<$applet_counter-1 and $i<50; $i++) {
			addAppletLTR($i);
		}
		addDividers();
	}
}

# NF = not formatted; CF = color formatted

sub getDateNFCF {
	my $date_format=$settings{"date_format"};
	my $raw_date = `date +$date_format`;
	my $nf="";
	my $cf="";
#	#print ("Date setting: $date_format\n");
#	#print ("Date: $nf\n");
	chomp ($raw_date);
	if (length($raw_date) > $APPLETS_MAX_WIDTHS{"date"}) {
		die ("Error: date string too long.\n");
	}
	my ($date_div_char)=($raw_date=~/^\d+(.)/);
	my @date_array = split (/$date_div_char/,$raw_date);

	# add the first date term separately bc no preceding divider
	if (exists $date_array[0]) {
		$nf .= $date_array[0];
		$cf .= $COLORS{"DATE"}.$date_array[0];
	}
	for (my $i=1; $i<@date_array; $i++) {
		$nf .= $date_div_char.$date_array[$i];
		$cf .= $COLORS{"DASH"}.$date_div_char;
		$cf .= $COLORS{"DATE"}.$date_array[$i];
	}

	return ($nf, $cf); #returns both. we need unformatted for a character count at the end
}

sub getTimeNFCF {
	my $raw_time = `date +$settings{"time_format"}`;
	my $nf="";
	my $cf="";
	chomp ($raw_time);
	if (length($raw_time) > $APPLETS_MAX_WIDTHS{"time"}) {
		die ("Error: time string too long.\n");
	}
	my ($time_div_char) = ($raw_time=~/^\d+(.)/);
	my @time_array = split (/$time_div_char/, $raw_time);
	
	# add first time term separately bc no preceding divider
	if (exists $time_array[0]) {
		$nf .= $time_array[0];
		$cf .= $COLORS{"TIME"}.$time_array[0];
	}
	for (my $i=1; $i<@time_array; $i++) {
		$nf .= $time_div_char.$time_array[$i];
		$cf .= $COLORS{"COLON"}.$time_div_char;
		$cf .= $COLORS{"TIME"}.$time_array[$i];
	}
	
	return ($nf, $cf);
}

sub getVolumeNFCF {
	if ($os eq "OpenBSD") {
		my @rawvol = split( /\n/, `sndioctl`);
		my $nf="NONE";
		my $cf="";
		foreach (@rawvol) {
			if ($_=~/output\.mute=1/) {
				$nf="muted";
				last;
			} elsif ($_=~/output\.level=/) {
				($nf)=($_=~/output\.level=(.*)/);
			}
		}
		if ($nf eq "NONE") {
			die ("Error: unable to read volume from sndioctl.\n");
		}
		
		if ($nf eq "muted") {
			$nf = "audio muted";
			$cf = $COLORS{"LABEL"}."audio ".$COLORS{"MUTE"}."muted";
		} else {
			chomp ($nf);
			$nf=$nf+0;
			$nf*=100;
			$nf=int($nf);
			if (length("audio $nf\%") > $APPLETS_MAX_WIDTHS{"volume"}) {
				die ("Error: volume string too long.\n");
			}
			$cf = $COLORS{"LABEL"}."audio ".$COLORS{"VOLUME"}.$nf.$COLORS{"UNITS"}."\%";
			$nf = "audio ".$nf."\%";
		}
		return ($nf, $cf);
	}
	else {
		die ("sorry dog only OpenBSD rn\n");
	}
}

sub getWifiNFCF {
	if ($os eq "OpenBSD") {
		my $interface = $settings{"wifi_interface"};
		my @rawwifi = split( /\n/, `ifconfig $interface`);
		my $nf="NONE";
		my $cf="";
		foreach (@rawwifi) {
			if ($_=~/status/) {
				($nf)=($_=~/status(.*)/);
				if ($nf=~/active/) {
					$nf="wifi up";
					$cf=$COLORS{"LABEL"}."wifi ".$COLORS{"GOOD"}."up";
				} elsif ($nf=~/no network/) {
					$nf="wifi down";
					$cf=$COLORS{"LABEL"}."wifi ".$COLORS{"BAD"}."down";
				} else {
					$nf = "wifi err";
					$cf = $COLORS {"LABEL"}."wifi ".$COLORS{"BAD"}."err";
				}
				last;
			}
		}
		if ($nf eq "NONE") {
			die ("Error: unable to read status of wifi interface $interface.\n");
		}
		chomp ($nf);

		if (length($nf) > $APPLETS_MAX_WIDTHS{"volume"}) {
			die ("Error: volume string too long.\n");
		}
		
		return ($nf, $cf);
	}
	else {
		die ("sorry dog only OpenBSD rn\n");
	}
}

sub getBatNFCF {
	my $nf="";
	my $cf="";
	my $bat_or_ac="";
	my $bat_capacity="";
	
	my $bat_or_ac_read=0;
	my $bat_capacity_read=0;
	
	if ($os eq "OpenBSD") {
		my @apm_output = split(/\n/, `apm`);

		for (my $i=0; $i<@apm_output; $i++) {
			if ($apm_output[$i]=~/AC adapter state: not connected/) {
				$bat_or_ac = "bat";
				$bat_or_ac_read=1;
			} elsif ($apm_output[$i]=~/AC adapter state: connected/) {
				$bat_or_ac = "ac";
				$bat_or_ac_read=1;
			} elsif ($apm_output[$i]=~/Battery state:.* \d+(?=%)/) {
				($bat_capacity) = ( $apm_output[$i]=~/Battery state:.* (\d+)(?=%)/ );
				$bat_capacity_read=1;
			}
		}
		unless ($bat_capacity_read==1 and $bat_or_ac_read==1) {
			die ("Unable to read apm output.\n");
		}
		$nf = $bat_or_ac." ".$bat_capacity."\%";
		$cf = $COLORS{"LABEL"}.$bat_or_ac." ";
		$cf .= $COLORS{"NUMBER"}.$bat_capacity.$COLORS{"UNITS"}."\%";
	}
	return ($nf, $cf);
}

sub getVPN_NFCF { ##################################### Doesn't work at all yet
	my $nf="";
	my $cf="";
	my $raw_vpn_output="";
	if ($vpn eq "wg") {
		$raw_vpn_output=`wg show wg0`;
		
	}
	return ($nf,$cf);
}

sub getFanSpeedNFCF {
	my $nf="";
	my $cf="";
	my $rpms="";
	if ($os eq "OpenBSD") {
		my @raw_fan_output=split(/\n/,`sysctl hw.sensors`);
		foreach (@raw_fan_output) {
			if ($_=~/.*\.fan0=\d+.*RPM/) {
				($rpms) = ($_=~/.*\.fan0=(\d+)/);
				$nf .= "fan ".$rpms." rpm";
				$cf .= $COLORS{"LABEL"}."fan ";
				$cf .= $COLORS{"NUMBER"}.$rpms;
				$cf .= $COLORS{"UNITS"}." rpm";
				last;
			}
		}
		if ($nf eq "") {
			$nf .= "fan err";
			$cf .= $COLORS{"LABEL"}."fan ";
			$cf .= $COLORS{"BAD"}." err";
		}
	}
	return ($nf, $cf);
}

sub getCPUTempNFCF {
	my $nf="";
	my $cf="";
	my $cpu_temp="";
	my $c_or_f="C";
	my $DEGREE_SYMBOL="\xc2\xb0";
	if ($os eq "OpenBSD") {
		my @raw_cpu_output=split(/\n/,`sysctl hw.sensors`);
		foreach (@raw_cpu_output) {
			if ($_=~/.*degF/) {
				$c_or_f="F";
			}
			if ($_=~/.*\.cpu0.temp0=\d+/) {
				($cpu_temp) = ($_=~/.*\.cpu0.temp0=(\d+)/);
				$nf .= "cpu ".$cpu_temp.$DEGREE_SYMBOL.$c_or_f;
				$cf .= $COLORS{"LABEL"}."cpu ";
				$cf .= $COLORS{"NUMBER"}.$cpu_temp;
				$cf .= $COLORS{"UNITS"}.$DEGREE_SYMBOL.$c_or_f;
				last;
			}
			if ($nf eq "") {
				$nf .= "fan err";
				$cf .= $COLORS{"LABEL"}."cpu ";
				$cf .= $COLORS{"BAD"}." err";
			}
		}
	}
	return ($nf, $cf);
}	
			

sub getDisplayStringsNFCF() { #mostly for debugging at this point
	setAppletsToDisplay();
	
	my $dscf=""; #display string color formatted
	my $dsnf=""; #display string not formatted
	my $stopper = 50;
	
	for (my $i=0; $i<@display_divided_LTR_array and $i<$stopper; $i++) {
#		#print ("$display_divided_LTR_array[$i]\n");
		if ($display_divided_LTR_array[$i] eq "date") {
			my ($datenf, $datecf) = getDateNFCF();
			$dscf .= $datecf;
			$dsnf .= $datenf;
		} elsif ($display_divided_LTR_array[$i] eq "time") {
			my ($timenf, $timecf) = getTimeNFCF();
			$dscf .= $timecf;
			$dsnf .= $timenf;
		} elsif ($display_divided_LTR_array[$i] eq "volume") {
			my ($volumenf, $volumecf) = getVolumeNFCF();
			$dscf .= $volumecf;
			$dsnf .= $volumenf;
			#print ($dscf);
		} elsif ($display_divided_LTR_array[$i] eq "wifi") {
			my ($wifinf, $wificf) = getWifiNFCF();
			$dscf .= $wificf;
			$dsnf .= $wifinf;
#			#print ($dscf);
		} elsif ($display_divided_LTR_array[$i] eq "battery_ac") {
			my ($batnf, $batcf) = getBatNFCF();
			$dscf .= $batcf;
			$dsnf .= $batnf;
		} elsif ($display_divided_LTR_array[$i] eq "fan_speed") {
			my ($fannf, $fancf) = getFanSpeedNFCF();
			$dscf .= $fancf;
			$dsnf .= $fannf;
		} elsif ($display_divided_LTR_array[$i] eq "cpu_temp") {
			my ($cpunf, $cpucf) = getCPUTempNFCF();
			$dscf .= $cpucf;
			$dsnf .= $cpunf;
		} elsif ($display_divided_LTR_array[$i] eq "tail") {
			$too_small_to_show_applets_flag=1;
		} else {
			die ("Error: cannot print applet $display_divided_LTR_array[$i]\n");
		}
		if (exists $display_divided_LTR_array[$i+1] and 
				$display_divided_LTR_array[$i+1] ne "tail" 
					and $display_divided_LTR_array[$i+1] ne "") {
			$dscf .= $COLORS{"DIVIDER"};
			$dscf .= $DIVIDERS{$display_divided_LTR_array[$i+1]};
			$dsnf .= $DIVIDERS{$display_divided_LTR_array[$i+1]};
			$i++;
		} else {
			$i=50;
		}
#		$display_string += "\n"; # right now I like it with no line breaks
	}
	my $leading_spaces=getLeadingSpaces($dsnf);
	$dsnf = $leading_spaces.$dsnf;
	$dscf = $leading_spaces.$dscf;
	return ($dsnf, $dscf);
}

sub getLeadingSpaces { # takes display string with no formatting as an arg
	my $dsnf = $_[0];
	my $length = length ($dsnf);

	my $terminal_width = getTerminalWidth();
	my $leading_spaces="";
	my $indent=$settings{"indent"};
	#if ( $length > $terminal_width+$indent) {
	#	die ("Error: display string width $length, terminal width only $terminal_width.\n");
	#} els
	if ($settings{"alignment"} eq "left") {
		$leading_spaces = ' 'x $indent;
	} elsif ($settings{"alignment"} eq "center") {
		my $n = ($terminal_width-$length)/2;
		if ($n<0) {
			die ("Error: negative leading spaces\n");
		}
		$leading_spaces = ' ' x $n;
	} else { # defaults to right aligned
		my $n = ($terminal_width-$length-$indent);
#		print ("terminal width: $terminal_width\n");
#		print ("display string length: $length\n");
#		print ("leading spaces: $n\n");
		if ($n < 0) {
			die ("Error: negative leading spaces\n");
		}
		$leading_spaces = ' ' x $n;
	}
	return ($leading_spaces);
}

sub getFirstPriorityAppletMaxWidth {
	if (exists $priority_array[0]) {
		return ($APPLETS_MAX_WIDTHS{$priority_array[0]});
	} else {
		die ("First priority applet not found.\n");
	}
}

sub printApplets {
	my ($dsnf, $dscf) = getDisplayStringsNFCF();
	#my $trailing_spaces = ' ' x $settings{"indent"};
	#$dscf=$dscf.$trailing_spaces;

	# if too small for a single applet, print empty spaces
	if (getTerminalWidth() < getFirstPriorityAppletMaxWidth()+2+$settings{"indent"}) {
	#	my $empty_string = ' ' x getTerminalWidth();
	#	print ("\r$empty_string");
		clearScreen();
	} else {
		if ($dscf ne $PREVIOUS_DISPLAY_STRING_CF
			or $PREVIOUS_TERMINAL_HEIGHT!=getTerminalHeight()) {
			clearScreen();
			print ("\r$dscf");
			$PREVIOUS_DISPLAY_STRING_CF=$dscf;
			$PREVIOUS_TERMINAL_HEIGHT=getTerminalHeight();
			
		}
	}
	# print a snail logo
	if ($settings{"snail_logo"} eq "1") {
		printSnailLogo();
	}
	setCursorInvisible();
}

sub setCursorInvisible {
	#print ("\e]12;#000000\a");
	print ("\e[?25l");
}

sub setCursorVisible {
	#print ("\e]12;#FFFFFF\a");
	print ("\e[?25h");
}

sub setBackgroundBlack {
	print ("\r\e]11;#000000\a\r");
#	print ("\e[2K"); # escape sequence to delete entire line
	my $empty_string = ' ' x getTerminalWidth();
	print ("\r$empty_string");	
}

sub eraseLine {
	my $blank_line='x' x getTerminalWidth();
	print ("\r$ANSI_COLORS{BLACK}$blank_line");
}

sub clearScreen {
	print ("\e[H\033[2J");
}

sub printSnailLogo() {
	print ("\r\e[38;2;90;76;3m\@\e[38;2;85;107;47my$COLORS{NORMAL}"); #snail logo
}

#### this one just resets the cursor color before exiting
# doesn't really work, because I can't tell what the original cursor color was lol
# this code just has to be somewhere above where we actually print stuff

$SIG{INT} = sub {
	setCursorVisible();
#	setBackgroundBlack();
#	print ("\e[0m");
	print ("\n");
	exit (0);
};



##################################
#											#
#		actually do it					#
#											#
##################################


setAppletsMaxWidths();
clearScreen();
printApplets ();

$| = 1; # this is to make sleep() actually work

while (1) {
	sleep ($settings{"poll_delay"});
	my $test = "x";  
	setAppletsMaxWidths();
#	eraseLTRLists();
#	print (" ");
	printApplets();
#	$i++;
	#	sleep ($settings{"poll_delay"});
}



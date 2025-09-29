#!/usr/bin/env perl

#use strict;
use warnings;

binmode(STDOUT, ":utf8");

my @errors;

# Perl note: backticks use /bin/sh
# /bin/sh is just a shortcut for ksh, bash or whatever

#################################################
#	Get all of the relevant system settings		#
#################################################

# get operating system
# determines which shell commands we got

my @ACCEPTABLE_OS = ("OpenBSD", "Linux");
my $os="err";
my $uname_output = `uname -s`;
foreach (@ACCEPTABLE_OS) {
	if ($uname_output =~ /$_/) {
		$os = $_;
		last;
	}
}
if ($os eq "err") {
	push (@errors, "Error: operating system not recognized.\n");
	die(@errors);
}

#get wifi command

my @ACCEPTABLE_WIFI_COMMANDS = ("ifconfig");
my $wifi_interface="err";
if ($os eq "OpenBSD") {
	$wifi_interface="iwx0";
} elsif ($os eq "Linux") {
	my $wifi_command;
	my @raw_wifi_command_output;
	foreach (@ACCEPTABLE_WIFI_COMMANDS) {
		if (`whereis $_` =~ /\/$_/) {
			$wifi_command = $_;
			last;
		}
	}
	@raw_wifi_command_output = `$wifi_command`;
	foreach (@raw_wifi_command_output) {
		if ($_ =~ /^w.*BROADCAST/) {
			($wifi_interface) = $_=~/^(w.*):/;
			last;
		}
	}
}	
if ($wifi_interface eq "err") {
	push (@errors, "Error: wifi interface not found.\n");
}
			

#get sound mixer

my @ACCEPTABLE_SOUND_MIXERS=("sndioctl", "wpctl", "pamixer", "amixer");
my $sound_mixer="err";

foreach (@ACCEPTABLE_SOUND_MIXERS) {
	if (`whereis $_` =~ /\/$_/) {
		$sound_mixer = $_;
		last;
	}
}
if ($sound_mixer eq "err") {
	push (@errors, "Error: sound mixer not found\n");
	die (@errors);
}

# get sensors command if linux

my @ACCEPTABLE_SENSOR_COMMANDS = ("sensors");
my $sensor_command="err";
foreach (@ACCEPTABLE_SENSOR_COMMANDS) {
	if (`whereis $_` =~ /\/$_/) {
		$sensor_command = $_;
		last;
	}
}
if ($sensor_command eq "err" and $os eq "Linux") {
	push (@errors, "Error: sensors not found\n");
}

#get VPN type
# this check should really get moved to when we read the applet list
# because probably most people don't even use or care about vpn

my @ACCEPTABLE_VPNS=("mullvad", "wg");
my $vpn="err";

foreach (@ACCEPTABLE_VPNS) {
	my $whereis_output=`whereis $_`;
	if ($whereis_output=~/\/$_/) {
		($vpn)=$_;
		last;
	}
}
if ($vpn eq "err") {
	push (@errors, "Error: vpn $vpn not recognized\n");
}

# get config file

my $HOME=`echo \$HOME`;
chomp($HOME);
my @ACCEPTABLE_CONFIG_FILES=("./.snailrc", "$HOME/.snailrc", "$HOME/.config/snailrc", "/etc/snailrc");
my $config_file="DEFAULTS";

foreach (@ACCEPTABLE_CONFIG_FILES) {
	if (-e $_) {
		$config_file=$_;
		last;
	}
}


#################################################
#	Read and parse the config file					#
#################################################


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
	"LIGHT_WHITE",
	"WHITE",
	"BLINK",
	"OLIVE",
	"BROWN"
);

# default settings and flags so that we can be sure they all get set

my @ACCEPTABLE_SETTINGS=(
	"poll_delay",
	"date_format",
	"time_format",
	"wifi_interface",
	"indent",
	"cursor",
	"snail_position",
	"snail_logo",
	"default_theme",
	"alignment",
	"cpu_temp_warn_threshold",
	"cpu_temp_ok_threshold",
	"cpu_temp_good_threshold",
	"volume_warn_threshold",
	"battery_warn_threshold",
	"battery_ok_threshold",
	"battery_good_threshold"
);

my %settings = (
	"poll_delay" => ".5",
	"small_applets" => "1",
	"date_format" => "\%Y-\%m-\%d",
	"time_format" => "\%H:\%M",
	"alignment" => "right",
	"wifi_interface" => $wifi_interface,
	"indent" => "1", #indent less than one totally fucks everything if right-aligned
	"cursor" => "left",
	"snail_position" => "left",
	"snail_logo" => "1",
	"default_theme" => "1"
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
	"LIGHT_WHITE" => "\e[1;97;40m",
	"WHITE" => "\e[1;97;40m",
	"OLIVE" => "\e[38;2;85;107;47m",
	"BROWN" => "\e[38;2;90;76;3m"
);

my %DEFAULT_THEME_COLORS = (
	"BLACK" => "\e[1m\e[38;2;0;0;0m",
	"RED" => "\e[1m\e[38;2;255;84;84m",
	"BLUE" => "\e[1m\e[38;2;116;178;255m",
	"GREEN" => "\e[1m\e[38;2;38;205;77m",
	"CYAN" => "\e[1m\e[38;2;133;220;133m",
	"MAGENTA" => "\e[1m\e[38;2;174;129;255m",
	"YELLOW" => "\e[1m\e[38;2;198;198;132m",
	"GREY" => "\e[1m\e[38;2;217;222;227m",
	"LIGHT_WHITE" => "\e[38;2;240;243;246m",
	"LIGHT_RED" => "\e[38;2;255;84;84m",
	"LIGHT_BLUE" => "\e[38;2;116;178;255m",
	"LIGHT_GREEN" => "\e[38;2;38;205;77m",
	"LIGHT_CYAN" => "\e[38;2;133;220;133m",
	"LIGHT_MAGENTA" => "\e[38;2;174;129;255m",
	"LIGHT_YELLOW" => "\e[38;2;198;198;132m",
	"LIGHT_GREY" => "\e[38;2;217;222;227m",
	"LIGHT_WHITE" => "\e[38;2;240;243;246m",
	"LIGHT_OLIVE" => "\e[38;2;85;107;47m",
	"LIGHT_BROWN" => "\e[38;2;90;76;3m"
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
my @RTL_array;
my @display_divided_LTR_array;
my @small_applets;
my $PREVIOUS_DISPLAY_STRING_CF="init";
my $PREVIOUS_TERMINAL_HEIGHT=getTerminalHeight();
my $too_small_to_show_applets_flag=0;
my $DEGREE_SYMBOL="\xb0";


my $LOGO_WIDTH = 3;

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
			push (@RTL_array, $1);
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
				push (@errors, "Error: color class $1 not recognized\n");
			}			
			
			($color_name) = ($_=~/=(.*)/);
			if (grep { $color_name eq $_ } @ACCEPTABLE_COLOR_NAMES) {
				$COLORS{$color_class}=$ANSI_COLORS{$color_name};
				#print ("Color class $color_class set: $color_name\n");
			} else {
				push (@errors, "Error: color name $1 not recognized\n");
			}
		}
		# no else here, because everything else is ignored
		
		$number_of_small_applets=$small_applets_index;
		$APPLETS_MAX_WIDTHS{"small_applets"} = $number_of_small_applets;
	}
	close ($config_readline);
} else {  # default settings
	@RTL_array = ( # check this against the array before changing
		"time",
		"date",
		"battery_ac",
		"wifi",
		"volume"		
	);
	@priority_array = (
		"time",
		"date",
		"battery_ac",
		"wifi",
		"volume"
	);
}

# check for snail logo

if ($settings{"snail_logo"} eq "false" or $settings{"snail_logo"} eq "no" or int($settings{"snail_logo"}) <1) {
	$LOGO_WIDTH=0;
}

# check for hardcoded theme

if ($settings{"default_theme"} eq "true" or $settings{"default_theme"} eq "yes" or $settings{"default_theme"} eq 1) {
	%ANSI_COLORS = (
		"WHITE"=> $DEFAULT_THEME_COLORS{"WHITE"},
		"GREY" => $DEFAULT_THEME_COLORS{"GREY"},
		"BLUE" => $DEFAULT_THEME_COLORS{"BLUE"},
		"RED" => $DEFAULT_THEME_COLORS{"RED"},
		"GREEN" => $DEFAULT_THEME_COLORS{"GREEN"},
		"YELLOW" => $DEFAULT_THEME_COLORS{"YELLOW"},
		"CYAN" => $DEFAULT_THEME_COLORS{"CYAN"},
		"MAGENTA" => $DEFAULT_THEME_COLORS{"MAGENTA"},
		"BLACK" => $DEFAULT_THEME_COLORS{"BLACK"},
		"LIGHT_GREY" => $DEFAULT_THEME_COLORS{"LIGHT_GREY"},
		"LIGHT_BLUE" => $DEFAULT_THEME_COLORS{"LIGHT_BLUE"},
		"LIGHT_RED" => $DEFAULT_THEME_COLORS{"LIGHT_RED"},
		"LIGHT_GREEN" => $DEFAULT_THEME_COLORS{"LIGHT_GREEN"},
		"LIGHT_YELLOW" => $DEFAULT_THEME_COLORS{"LIGHT_YELLOW"},
		"LIGHT_CYAN" => $DEFAULT_THEME_COLORS{"LIGHT_CYAN"},
		"LIGHT_MAGENTA" => $DEFAULT_THEME_COLORS{"LIGHT_MAGENTA"},
		"OLIVE" => "\e[1m\e[38;2;85;107;47m",
		"BROWN" => "\e[1m\e[38;2;90;76;3m"
	);
	%COLORS = (
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
	#	"VERY_BAD" => "BLINK", # its special
		"BACKGROUND" => $ANSI_COLORS{"BLACK"}
	);
}

# check that all applets in priority listing are in RTL listing


#foreach (@priority_array) {
#	unless (exists @RTL_list{$_}) {
#		die ("Error: applet $_ appears in priority list but not in RTL list\n");
#	}
#}


#########################################################
#	Figure out how big the window is and which	#
#	applets to display				#
#########################################################

sub generateUndividedAppletDisplayListRTL {
	my $n=$_[0];
	my %display_flags;
	my @output_ordered_list;
	for (my $i=0; $i<$n; $i++) {
		$display_flags{$priority_array[$i]}=1;
	}
	foreach (@RTL_array) {
		if (exists $display_flags{$_}) {
			push (@output_ordered_list, $_);
		}
	}
	return (@output_ordered_list);
}

sub generateDividedAppletDisplayListRTL {
	my $n=$_[0];
	my @undivided_array=generateUndividedAppletDisplayListRTL($n);
	my @divided_array;
	
	if (exists $undivided_array[0]) {
		push (@divided_array, $undivided_array[0]);
	}
	
	for (my $i=1; $i<@undivided_array; $i++) {
		if ( ($undivided_array[$i] eq "date" and $undivided_array[$i-1] eq "time")
			or ($undivided_array[$i] eq "time" and $undivided_array[$i-1] eq "date") ) {
			push (@divided_array, "small_divider");
		} else {
			push (@divided_array, "big_divider");
		}
		push (@divided_array, $undivided_array[$i]);
	}
	
	return (@divided_array);
}

sub getAppletListMaxLength {
	my @divided_array=@_;
	my $max_length=0;
	
	setAppletsMaxWidths();
	
	foreach (@divided_array) {
		$max_length += $APPLETS_MAX_WIDTHS{$_};
	}
	$max_length += 2*$settings{"indent"};
	
	if ($settings{"snail_logo"} eq "yes" or $settings{"snail_logo"} eq "true" or
		int($settings{"snail_logo"})>0) {
		$max_length+=3;
	}
	return($max_length);
}

sub generateDisplayLTRArray { #no args
	my @display_RTL_array;

	# it is easier to start at the top and work our way down
	# because then the first one under max length, just keep it
	# if we work our way up, we have to overshoot and then step back
	for (my $i=@priority_array; $i>0; $i--) {
		@display_RTL_array=generateDividedAppletDisplayListRTL($i);
		if ( getAppletListMaxLength(@display_RTL_array)<=getTerminalWidth() ) {
			last;
		}
	}
	
	# it makes more sense as a user input setting RTL
	# but it makes more sense to display as LTR.
	# so flip it.

	return ( reverse(@display_RTL_array) );
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

#########################################
#					#
# actually make the applets	#
#					#
#########################################	

# NF = not formatted; CF = color formatted

sub get_date_NFCF {
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

sub get_time_NFCF {
	my $raw_time = `date +$settings{"time_format"}`;
	my $nf="";
	my $cf="";
	chomp ($raw_time);
	if (length($raw_time) > $APPLETS_MAX_WIDTHS{"time"}) {
		push (@errors, "Error: time string too long.\n");
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

sub get_volume_NFCF {
	my $nf="NONE";
	my $cf="";
	if ($os eq "OpenBSD") {
		my @rawvol = split( /\n/, `sndioctl`);
		
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
	} elsif ($os eq "Linux") {
		my $volume = "";
		if ($sound_mixer eq "err") {
			$nf = "audio err";
			$cf = $COLORS{"LABEL"}."audio ".$COLORS{"BAD"}."err";
		}
		elsif ($sound_mixer eq "pamixer") {
			if (`pamixer --get-mute` =~ /true/) {
				$volume = "muted";
				$nf = "audio $volume";
				$cf = $COLORS{"LABEL"}."audio ".$COLORS{"GOOD"}.$volume;
			} else {
				$volume = `awk -F"[][]" '/Left:/ { print \$2 }' <(amixer sget Master)`;
				($volume) = $volume =~ /(\d+)/; #get rid of percent sign
				$nf = "audio $volume\%";
				$cf = $COLORS{"LABEL"}."audio ".$COLORS{"NUMBER"}.$volume.$COLORS{"UNITS"}."\%";
			}
		} elsif ($sound_mixer eq "amixer") {
			my @rawvol = `amixer get Master | tail -2`;
			$volume = "err";

			if ($rawvol[0] =~ /\[off\]/) { 
				
				$volume = "muted";
				$nf = "audio $volume";
				$cf = $COLORS{"LABEL"}."audio ".$COLORS{"GOOD"}.$volume;
			} else {
				foreach (@rawvol) {
					#print ("in the loop\n");
					if ($_ =~ /Front.*\[\d*\%\].*\[on\]/) {
					#	print ("In the if\n");
						($volume) = $_=~ /Front.*\[(\d*)\%\].*\[on\]/;
						last;
					}
				}
				if ($volume eq "err") {
					$nf = "audio $volume";
					$cf = $COLORS{"LABEL"}."audio ".$COLORS{"BAD"}.$volume;
				} else {
					$nf = "audio $volume\%";
					$cf = $COLORS{"LABEL"}."audio ".$COLORS{"NUMBER"}.$volume.$COLORS{UNITS}."\%";
				}
			}			
		} elsif ($sound_mixer eq "wpctl") {
			$volume = `wpctl get-volume \@DEFAULT_AUDIO_SINK\@`;
			if ($volume =~ /MUTED/) {
				$volume = "muted";
				$nf = "audio $volume";
				$cf = $COLORS{"LABEL"}."audio ".$COLORS{"GOOD"}.$volume;
			} else {
				($volume) = $volume =~ /.*(\d\.\d*)/;
				$volume = 100*$volume;
				$volume = int ($volume);
				$nf = "audio $volume\%";
				$cf = $COLORS{"LABEL"}."audio ".$COLORS{"NUMBER"}.$volume.$COLORS{"UNITS"}."\%";
			}
		}
				
	}
		
	return ($nf, $cf);
	
}

sub get_wifi_NFCF {
	if ($os eq "OpenBSD") { #right now just works with ifocnfig
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
			push (@errors, "Error: unable to read status of wifi interface $interface.\n");
			$wifi_interface="err";
		}
		
		chomp ($nf);

		if (length($nf) > $APPLETS_MAX_WIDTHS{"wifi"}) {
			die ("Error: volume string too long.\n");
		}
		
		return ($nf, $cf);
	} elsif ($os eq "Linux") {
		my $interface = $settings{"wifi_interface"};
		my @rawwifi = split( /\n/, `ifconfig $interface`);
		my $nf="NONE";
		my $cf="";
		if ($rawwifi[0]=~/$interface/) {
			#($nf)=($rawwifi[0]=~/($interface)/);
			#print ("$nf\n");
			if ($rawwifi[0]=~/RUNNING/) {
				$nf="wifi up";
				$cf=$COLORS{"LABEL"}."wifi ".$COLORS{"GOOD"}."up";
			} elsif ($nf=~/BROADCAST/) {
				$nf="wifi down";
				$cf=$COLORS{"LABEL"}."wifi ".$COLORS{"BAD"}."down";
			} else {
				$nf = "wifi err";
				$cf = $COLORS {"LABEL"}."wifi ".$COLORS{"BAD"}."err";
			}
		} else {
			die ("Error: unable to read status of wifi interface $interface.\n");
		}
		chomp ($nf);

		if (length($nf) > $APPLETS_MAX_WIDTHS{"wifi"}) {
			die ("Error: volume string too long.\n");
		}
		if ($wifi_interface eq "err") {
			$nf = "wifi err";
			$cf = $COLORS{"LABEL"}."wifi ".$COLORS{"BAD"}."err";
		}
		return ($nf, $cf);
	}
}

sub get_battery_ac_NFCF {
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
			push (@errors, "Unable to read apm output.\n");
		}
		$nf = $bat_or_ac." ".$bat_capacity."\%";
		$cf = $COLORS{"LABEL"}.$bat_or_ac." ";
		$cf .= $COLORS{"NUMBER"}.$bat_capacity.$COLORS{"UNITS"}."\%";
	} elsif ($os eq "Linux") {
		$bat_capacity=`cat /sys/class/power_supply/BAT0/capacity`;
		chomp ($bat_capacity);
		$bat_or_ac=`cat /sys/class/power_supply/BAT0/status`;
		chomp ($bat_or_ac);
		if ($bat_or_ac eq "Discharging") {
			$bat_or_ac = "bat";
		} else {
			$bat_or_ac = "ac";
		}
		$nf = $bat_or_ac." ".$bat_capacity."\%";
		$cf = $COLORS{"LABEL"}.$bat_or_ac." ";
		$cf .= $COLORS{"NUMBER"}.$bat_capacity.$COLORS{"UNITS"}."\%";
	}
	return ($nf, $cf);
}

sub get_vpn_NFCF { # only works for mullvad on linux rn
	my $nf="";
	my $cf="";
	my @raw_vpn_output;
	my $country="";
	if ($vpn eq "wg") {
		#@raw_vpn_output=`wg show wg0`;
		$nf="vpn err";
		$cf=$COLORS{"LABEL"}."vpn ".$COLORS{"BAD"}."err";
	} elsif ($vpn eq "mullvad") {
		@raw_vpn_output=split(/\n/,`mullvad status`);
		if ($raw_vpn_output[0] =~ /Disconnected/) {
			$nf="vpn down";
			$cf=$COLORS{"LABEL"}."vpn ".$COLORS{"BAD"}."down";
		} elsif ($raw_vpn_output[0] =~ /Connected/ and 
			$raw_vpn_output[1] =~ /.*Relay:\s*[a-zA-Z][a-zA-Z]\-/) {
			($country)=$raw_vpn_output[1]=~/.*Relay:\s*([a-zA-Z][a-zA-Z])\-/;
			$nf="vpn up";
			$cf=$COLORS{"LABEL"}."vpn ".$COLORS{"GOOD"}.$country;
		} else {
			$nf="vpn err";
			$cf=$COLORS{"LABEL"}."vpn ".$COLORS{"BAD"}."err";
		}
	}		
	return ($nf,$cf);
}

sub get_fan_speed_NFCF {
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
	} elsif ($os eq "Linux" and $sensor_command="sensors") {
		my @raw_fan_output=split(/\n/, `sensors | grep -i fan`);
		#print ("Raw fan output 0: $raw_fan_output[0]\n");
		if ($raw_fan_output[0] =~ /fan.*:\s+\d+\s+RPM/) {
			($rpms) = $raw_fan_output[0] =~ /fan.*:\s+(\d+)\s+RPM/;
			$nf="fan $rpms rpm";
			$cf= $COLORS{"LABEL"}."fan ".$COLORS{"NUMBER"}.$rpms.$COLORS{"UNITS"}." rpm";
		} else {
			$nf="fan err";
			$cf= $COLORS{"LABEL"}."fan ".$COLORS{"BAD"}." err";
		}
	} else {
		$nf="fan err";
		$cf= $COLORS{"LABEL"}."fan ".$COLORS{"BAD"}." err";
	}
	return ($nf, $cf);
}

sub get_cpu_temp_NFCF {
	my $nf="";
	my $cf="";
	my $cpu_temp="err";
	my $c_or_f="C";
	
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
	} elsif ($os eq "Linux" and $sensor_command="sensors") {
		my $raw_cpu_output=`sensors | grep -i 'CPU'`;
		if ($raw_cpu_output =~ /CPU\s*:.*\d+/) {
			($cpu_temp) = $raw_cpu_output =~ /CPU\s*:\s*\+(\d+)/;
			$nf="cpu $cpu_temp*C";
			$cf= $COLORS{"LABEL"}."cpu ".$COLORS{"NUMBER"}.$cpu_temp.$COLORS{"UNITS"}.$DEGREE_SYMBOL.$c_or_f;
		} else {
			$nf="cpu err";
			$cf= $COLORS{"LABEL"}."cpu ".$COLORS{"BAD"}."err";
			push (@errors, "CPU temp not read\n");
		}
	} else {
		$nf="cpu err";
		$cf= $COLORS{"LABEL"}."fan ".$COLORS{"BAD"}." err";
		push (@errors, "CPU temp not read\n");
	}
	return ($nf, $cf);
}	

sub get_small_divider_NFCF {
	my $nf =$DIVIDERS{"small_divider"};
	my $cf =$COLORS{"DIVIDER"}.$DIVIDERS{"small_divider"}.$COLORS{"NORMAL"};
	return ($nf, $cf);
}

sub get_big_divider_NFCF {
	my $nf =$DIVIDERS{"big_divider"};
	my $cf =$COLORS{"DIVIDER"}.$DIVIDERS{"big_divider"}.$COLORS{"NORMAL"};
	return ($nf, $cf);
}
			

sub getDisplayStringsNFCF() { 
	my @display_list_ltr=generateDisplayLTRArray();

	my $dsnf=""; #display string not formatted
	my $dscf=""; #display string color formatted
	
	for (my $i=0; $i<@display_list_ltr; $i++) {
		my $applet_command="get_".$display_list_ltr[$i]."_NFCF";
		my ($applet_nf, $applet_cf) = &{$applet_command}();
		$dsnf .= $applet_nf;
		$dscf .= $applet_cf;
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
	
	if ($settings{"alignment"} eq "left") {
		$leading_spaces = ' 'x ($indent+$LOGO_WIDTH);
	} elsif ($settings{"alignment"} eq "center") {
		my $n = ($terminal_width-$length)/2;
		if ($n<0) {
			$n=0;
			push (@errors, "Error: negative leading spaces\n");
		}
		$leading_spaces = ' ' x $n;
	} else { # defaults to right aligned
		my $n = ($terminal_width-$length-$indent);
		if ($n < 0) {
			$n=0;
			push (@errors, "Error: negative leading spaces\n");
		}
		$leading_spaces = ' ' x $n;
	}
	return ($leading_spaces);
}

sub getFirstPriorityAppletMaxWidth {
	if (exists $priority_array[0]) {
		return ($APPLETS_MAX_WIDTHS{$priority_array[0]});
	} else {
		push (@errors, "First priority applet not found.\n");
	}
}

sub printApplets {
	my ($dsnf, $dscf) = getDisplayStringsNFCF();

	if (getTerminalWidth() < getFirstPriorityAppletMaxWidth()+2+$settings{"indent"}) {
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

#sub setCursorVisible {
#	print ("\e[?25h");
#}

sub setBackgroundBlack {
	print ("\r\e]11;#000000\r");
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
	print ("\r");
	print ($ANSI_COLORS{"OLIVE"}."_".$ANSI_COLORS{"BROWN"}."\@".$ANSI_COLORS{"OLIVE"}."y".$COLORS{"NORMAL"}); #snail logo
}

#### this one just resets the cursor color before exiting
# doesn't really work, because I can't tell what the original cursor color was lol
# this code just has to be somewhere above where we actually print stuff

$SIG{INT} = sub {
#	setCursorVisible();
	print ("\n");
	if (exists $errors[0]) {
		die (@errors);
	}
	exit (0);
};



#########################################
#					#
#		actually do it		#
#					#
#########################################


setAppletsMaxWidths();
clearScreen();
printApplets ();

$| = 1; # this is to make sleep() actually work

while (1) {
	sleep ($settings{"poll_delay"});
	setAppletsMaxWidths();
	printApplets();
}



# snail
Snail is a tray application that runs in a console, intended to work with a manual tiling window manager. It is called snail because I like snails.

---

Snail is easy to install: 
  Run "git clone https://github.com/nicholasrupert/snail.git"
  Run "sudo install.sh" on Linux or "doas install.sh" on OpenBSD.
  Then run "snail".
  If you want to run it without installing it, you can just run "perl snail.pl".
 
  The only dependency is "sensors", if running on Linux. OpenBSD should work out of the box. No support for other OSes right now.

  If that doesn't work, post a comment.
  
--- 

What is the point of this program?

  Suppose you have a manual tiling window manager with no window borders. Then you probably like screen real estate a lot.
  So you probably don't want a menu bar that goes all the way across your screen. This is frequently built into even manual tiling window managers.
  Snail just runs in a window (or a terminal), so you can make it as wide or as narrow as you want.
  Sometimes you might even be resizing the window that has your menubar in it, and so it needs to smoothly display more or less information.
  This one does that. If you shrink it down, you get just the time. Make it wide, you get everything.
  You can easily customize the ordering in which applets appear or disappear, and easily customize the right-to-left order.
  You can have the applets display left aligned, centered, or right aligned.
  If you use a manual tiling window manager, you probably also like terminal-ish esthetics. This does that.
  By default it uses whatever terminal theme you are using, but you can manually change the colors in the config file.
 
  If you feel like customizing it, you can look at .snailrc and mess with it. It looks in ~/.snailrc, then ~/.config/snailrc, then /etc/snailrc.
  If you think it's missing an applet, or an applet could be expanded to support more stuff, post a comment.
  If you think my code is garbage, post a comment.

Why is it in Perl?
  This program basically just parses text output of a bunch of different GNU and Unix utilities. It is a glorified shell script.
  Perl is for that, with basically C-like syntax, so it is easy. I don't know why it has lost popularity, it's great.
  Also Perl is already on your machine. I hate installing dependencies, don't you?

---

Working applets:
- Date (custom format allowed with unix date format setting, e.g. Y-m-d)
- Time (custom format allowed with unix date format setting, e.g. H:M)
- Battery/AC
- Audio volume/mute status
- Wifi status (sort of)
- VPN status (sort of)
- CPU temperature
- Fan speed

Linux requires "sensors" installed to have cpu/fan data. OpenBSD should work out of the box. All tested.

Supported VPNs: mullvad only, only on Linux.

Supported audiomixers: amixer, pamixer, wpctl, sndioctl (OpenBSD), all tested.

Actually tested shells: Bash and Korn. Allows csh and zsh, but these are untested.

Actually tested terminals: alacritty, fish, xterm. Xterm has some weird behavior where the background color does not instantly update.

CPU temp currently assumes Celsius.

---

To do:

- More testing.
- Get wireguard to work.
- Improve behavior when snail logo turned off.
- See whether popular VPNs I don't use need separate support.
- Add applets for RAM, swap, and disk usage.
- Make small applets work.
- Better error handling. Right now most errors kill the program with an error message.
- Add a default theme that is good.
- Allow users to pick warning thresholds for, e.g., battery percentage.
- Update .snailrc.example.
- Make it work on Linux without sensors installed, if possible.
- Figure out whether it is practical to have non-UTF-8 characters.
- Custom label support so that non-English-speakers can use it and have it be nice.
- Dynamically figure the maximum width of each applet, for better formatting and customization.
- Clean up code -- too many nested ifs/loops and too much duplicate code. Could use better comments and more consistent variable names.
- FreeBSD support? NetBSD? DragonflyBSD? Test on NixOS?
- The current method of figuring out which applets to display and in which order definitely works, but there has to be a cleaner way.

---

I might one day want to make it run at the top or bottom of an actively-used terminal window. 

#!/bin/sh

## language settings
export TEXTDOMAIN=hdsgui
export OUTPUT_CHARSET=UTF-8

[ -z "`which hdsentinel`" ] && Xdialog --icon /usr/local/lib/X11/pixmaps/error.png --beep --title "$(gettext 'Error!')" --left --msgbox "$(gettext 'Hard Disk Sentinel (hdsentinel) missing!
Please install it and try again.
Exiting...')" 0 0 && exit

#Verify if HDS GUI is already running and exit if yes
[ "$(ps ax | grep gtkdialog | grep HDS_GUI | awk '{print $1}')" ] && echo HDS GUI already running && exit

#create directories/link/default config file if not exist
[ -f "$HOME/Startup/hdsgui_systray" ] || ln -s /usr/local/hdsgui/hdsgui_systray $HOME/Startup/hdsgui_systray 2>/dev/null
[ -R "$HOME/.hdsgui" ] || mkdir $HOME/.hdsgui 2>/dev/null
if [ -f "$HOME/.hdsgui/supported" ]; then
	SUPPORTED="true"
	TXT_SUPPORTED="$(gettext 'Set hard disk(s) acoustic setting:') "
else
	SUPPORTED="false"
	TXT_SUPPORTED=" $(gettext '(NOT SUPPORTED)') "
fi
[ -f "$HOME/.hdsgui/config" ] || echo "DURATION=15
ACOUSTIC=false
SILENCE=false
HIGHPERF=true
STARTUP=true
" > $HOME/.hdsgui/config
[ -R "$HOME/.hdsgui/logs" ] || mkdir $HOME/.hdsgui/logs 2>/dev/null
[ -f "$HOME/.hdsgui/tab" ] && TAB="`cat $HOME/.hdsgui/tab`" || echo 0 $HOME/.hdsgui/tab

export VERSION=0.1
export DATE="`date`"
. $HOME/.hdsgui/config
. gettext.sh

#set default report type
echo $(gettext 'QUICK') > /tmp/HDS

warning () {
if [ "`grep "Failure Predicted" "$LOGFILE"`" ] || [ "`grep "Replace hard disk" "$LOGFILE"`" ] || [ "`grep "to prevent data loss" "$LOGFILE"`" ]; then
	Xdialog --icon /usr/local/lib/X11/pixmaps/warning48.png --beep --title "$(gettext 'WARNING!')" --left --msgbox "$(gettext 'One or several disk(s) connected to your motherboard
or an external controller card strongly requires your attention.')

$(gettext 'Please read carefully the report that will now be displayed...')" 0 0
fi
}
export -f warning

about () {
export ABOUT="
<window decorated=\"false\" skip_taskbar_hint=\"true\" window_position=\"2\">
<vbox border-width=\"5\">	
	<frame  $(gettext 'About') >
		<pixmap><input file>/usr/share/icons/hicolor/48x48/apps/hdsgui.png</input></pixmap>
		<text use-markup=\"true\"><label>\"<b><span size='large'>HDS GUI - v$VERSION</span></b>\"</label></text>
		<text use-markup=\"true\"><label>\"<b>$(gettext 'Basic GUI for hdsentinel 32/64 bit')</b>\"</label></text>
		<text use-markup=\"true\"><label>\"$(gettext 'Argolance <i>(March 2019)')</i>\"</label></text>
<hseparator height-request=\"10\"></hseparator>
		<pixmap><input file>/usr/local/lib/X11/mini-icons/hds_1.png</input></pixmap>
		<pixmap><input file>/usr/local/lib/X11/mini-icons/hds_2.png</input></pixmap>
		<text use-markup=\"true\"><label>\"<b><span size='large'>$(gettext 'Systray notification icon')</span></b>\"</label></text>
		<text use-markup=\"true\"><label>\"$(gettext 'Argolance <i>(March 2019)')</i>\"</label></text>
	</frame>
	<hbox>	
		<button can-focus=\"no\" relief=\"2\"><input file stock=\"gtk-close\"></input></button>
	</hbox>
</vbox>
</window>
"

gtkdialog4 --class St_Ab --program=ABOUT
}
export -f about

help() {
export HELP="
<window title=\"$(gettext 'HDS GUI') v$VERSION - $(gettext 'Help')\" icon-name=\"gtk-help\">
<vbox border-width=\"5\">
	<text use-markup=\"true\"><label>\"	<b>$(gettext 'Hard Disk Sentinel</b> <i>(hdsentinel)</i> gives information about the temperature and health status of IDE, S-ATA, SCSI and USB hard disk<i>(s)</i> connected to motherboard or external controller cards.
	<b>HDS GUI</b> creates a directory of log files at first run, allowing user to look at them then note any suspect changes and a warning blinking systray icon can be displayed if a disk requires attention...
<b>Notes:</b>
	It is the hard disk itself that detects the problems and <b>Hard Disk Sentinel</b> reads them, interprets and displays them exactly to increase the attention about the change and allow time to prepare<i>(for example)</i> doing a backup.
	The possible bad sectors reported in the text description are no longer used by the hard disk: they are already reallocated. So the spare area is used for all reads and writes targeting those bad sectors. This means that disk surface tests <i>(even the tests in <b>Hard Disk Sentinel</b>)</i> does not access those sectors, but tests the remaining data area and the spare area, so you can be sure that the original <i>(bad)</i> area does not contain important data and cannot risk data loss although having high number of reallocated sectors can be risky - as more problems may be expected with higher chance.
	By using the surface tests, you can verify if the currently used data area is error-free and if there are no further errors reported <i>(no weak, damaged sectors, no further problems).')</i>\"</label></text>
	<hbox>
		<button no-focus=\"true\" relief=\"2\">
			<input file stock=\"gtk-close\"></input>
		</button>
	</hbox>
</vbox>
</window>
"

gtkdialog4 -p HELP -c
}
export -f help

report () {
. gettext.sh

yaf-splash -placement top -bg grey90 -icon "/usr/share/pixmaps/dice.gif" -text "$(gettext 'Please wait, hdsentinel is collecting data...')" -close never &
	XPID=$!
if [ "$(cat /tmp/HDS)" = "$(gettext 'QUICK')" ]; then
	LOGFILE="$HOME/.hdsgui/logs/"${DATE}_$(gettext 'QUICK').log""
	sleep 1
	echo "******************************************************************************************************
	$(eval_gettext 'Hard Disk Sentinel - QUICK report - $DATE
******************************************************************************************************')
$(hdsentinel | grep -A 100 HDD)" > "$LOGFILE"
	kill $XPID
	warning
	gxmessage -borderless -wrap -fn Monospace -file "$LOGFILE" &
else
	LOGFILE="$HOME/.hdsgui/logs/"${DATE}_$(gettext 'FULL').log""
	sleep 1
	echo "******************************************************************************************************
	$(eval_gettext 'Hard Disk Sentinel - FULL report - $DATE
******************************************************************************************************')
$(hdsentinel -dump)" > "$LOGFILE"
	kill $XPID
	warning
	gxmessage -borderless -wrap -fn Monospace -file "$LOGFILE" &
fi
}
export -f report

export HDS_GUI="
<window title=\"$(gettext 'HDS GUI') v$VERSION\" icon-name=\"hdsgui\" resizable=\"false\" width-request=\"460\">
<vbox>
	<hbox>
		<button can-focus=\"no\" relief=\"2\" tooltip-markup=\" $(gettext 'Help') \">
			<input file stock=\"gtk-help\"></input>
			<action>help &</action>
		</button>
		<button can-focus=\"no\" relief=\"2\" tooltip-text=\" $(gettext 'About') \">
			<input file stock=\"gtk-about\"></input>
			<action>about &</action>
		</button>
	</hbox>
<notebook page=\"$TAB\" labels=\" $(gettext 'REPORT | HD ACOUSTIC SETTING | OPTIONS') \">
	<vbox border-width=\"5\">
		<frame  $(gettext 'Type of report to generate and display:') >
			<vbox space-fill=\"true\" space-expand=\"true\">
				<button>
					<label>\" $(gettext 'QUICK')\"</label>
					<input file>/usr/local/hdsgui/pictures/hds-quick.png</input>
					<action>echo \"0\" > $HOME/.hdsgui/tab</action>
					<action>echo $(gettext 'QUICK') > /tmp/HDS</action>
					<action>report &</action>
				</button>
				<button tooltip-text=\" $(gettext 'Full report with S.M.A.R.T parameters') \">
					<label>\" $(gettext 'FULL')\"</label>
					<input file>/usr/local/hdsgui/pictures/hds-full.png</input>
					<action>echo \"0\" > $HOME/.hdsgui/tab</action>
					<action>echo $(gettext 'FULL') > /tmp/HDS</action>
					<action>report &</action>
				</button>
			</vbox>
		</frame>
		<hbox>
			<text><label>\"$(gettext 'Open log files directory:') \"</label></text>
			<button>
				<input file stock=\"gtk-open\"></input>
				<action>echo \"0\" > $HOME/.hdsgui/tab</action>
				<action>rox $HOME/.hdsgui/logs &</action>
			</button>
		</hbox>
	</vbox>

	<vbox border-width=\"5\">
		<frame $TXT_SUPPORTED>
			<vbox space-fill=\"true\" space-expand=\"true\">
				<checkbox active=\"$ACOUSTIC\">
					<sensitive>$SUPPORTED</sensitive>
					<variable>ACOUSTIC</variable>
					<label>\"$(gettext 'Enable')\"</label>
					<action>echo \"1\" > $HOME/.hdsgui/tab</action>
					<action>if true enable:SILENCE</action>
					<action>if true enable:HIGHPERF</action>
					<action>if true enable:APPLY</action>
					<action>if false disable:SILENCE</action>
					<action>if false disable:HIGHPERF</action>
					<action>if false disable:APPLY</action>
				</checkbox>
				<radiobutton active=\"$SILENCE\">
					<sensitive>$ACOUSTIC</sensitive>
					<variable>SILENCE</variable>
					<label>\"$(gettext 'Optimize complete system for silence')\"</label>
					<action>echo \"1\" > $HOME/.hdsgui/tab</action>
				</radiobutton>
				<radiobutton active=\"$HIGHPERF\">
					<sensitive>$ACOUSTIC</sensitive>
					<variable>HIGHPERF</variable>
					<label>\"$(gettext 'Optimize complete system for high performance')\"</label>
					<action>echo \"1\" > $HOME/.hdsgui/tab</action>
				</radiobutton>
			</vbox>
		</frame>
		<vbox space-fill=\"false\" space-expand=\"false\">
			<hbox>
				<button tooltip-text=\" $(gettext 'Exit and save changes') \">
					<sensitive>$SUPPORTED</sensitive>
					<input file stock=\"gtk-apply\"></input>
					<variable>APPLY</variable>
					<action>echo \"1\" > $HOME/.hdsgui/tab &</action>
					<action>EXIT:apply</action>
				</button>  
			</hbox>
		</vbox>
	</vbox>

	<vbox border-width=\"5\">
		<vbox space-fill=\"true\" space-expand=\"true\">
			<frame  $(gettext 'Examine disk(s) configuration at Startup:') >
				<hbox space-fill=\"true\" space-expand=\"true\">
					<pixmap><input file>/usr/local/lib/X11/pixmaps/info.png</input></pixmap>
					<text use-markup=\"true\"><label>\"$(gettext 'A warning blinking systray icon can be displayed if any disk connected to the motherboard or an external controller card requires attention...') \"</label></text>
				</hbox>
				<hbox space-fill=\"true\" space-expand=\"true\">
					<checkbox active=\"$STARTUP\">
						<variable>STARTUP</variable>
						<label>\"$(gettext 'Enable')\"</label>
						<action>echo \"2\" > $HOME/.hdsgui/tab</action>
						<action>if true enable:DURATION</action>
						<action>if true enable:TEST</action>
						<action>if false disable:DURATION</action>
						<action>if false disable:TEST</action>
					</checkbox>
					<text use-markup=\"true\"><label>\"<i>$(gettext '(Display duration:')</i>\"</label></text>
					<spinbutton range-min=\"5\" range-max=\"60\" range-step=\"5\" range-value=\"$DURATION\" editable=\"false\">
						<variable>DURATION</variable>
						<sensitive>$STARTUP</sensitive>
					</spinbutton>
					<text use-markup=\"true\"><label>\"<i>$(gettext 'seconds)')</i>\"</label></text>
					<button tooltip-markup=\" $(eval_gettext 'Click this button to test the systray icon with current display duration: <b>$DURATION</b>.
 Note that the selected value is saved only if you click the Ok button.') \">
						<sensitive>$STARTUP</sensitive>
						<variable>TEST</variable>
						<label>\"$(gettext 'Test')\"</label>
						<input file stock=\"gtk-media-play\"></input>
						<action>echo \"2\" > $HOME/.hdsgui/tab</action>
						<action>EXIT:test</action>
					</button>
				</hbox>
			</frame>
		<vbox space-fill=\"false\" space-expand=\"false\">
			<hbox>
				<button tooltip-text=\" $(gettext 'Exit and save changes') \">
					<sensitive>$STARTUP</sensitive>
					<input file stock=\"gtk-apply\"></input>
					<action>echo \"2\" > $HOME/.hdsgui/tab &</action>
					<action>EXIT:apply</action>
				</button>  
			</hbox>
		</vbox>
		</vbox>
	</vbox>
</notebook>
	<hbox>
		<button tooltip-text=\" $(gettext 'Exit the program without saving changes') \" relief=\"2\">
			<input file stock=\"gtk-quit\"></input>
			<action>EXIT:exit</action>
		</button>
	</hbox>
</vbox>
</window>
"
I=$IFS; IFS=""
for STATEMENTS in $(gtkdialog --program=HDS_GUI); do
    eval $STATEMENTS
done
IFS=$I

[ "$EXIT" = "exit" ] || [ "$EXIT" = "abort" ] && exit
if [ "$EXIT" = "test" ]; then
	sleep 0.5
	while true; do echo 'icon:/usr/local/lib/X11/mini-icons/hds_1.png'; sleep 0.5; echo 'icon:/usr/local/lib/X11/mini-icons/hds_2.png'; sleep 0.5; done | yad --notification --icon-size=24 --auto-kill --no-middle --listen --text="----------------------
 <b>$(gettext 'WARNING!')</b>
----------------------
	<b>$(gettext 'One or several disk(s) connected to your motherboard
or an external controller card strongly requires your attention.')</b>
	$(gettext 'Please, click this systray icon to run HDS GUI...')" --command="hdsgui" &
	XPID1=$!
	sleep $DURATION
	kill $XPID1 &
	exit
fi

#save current parameters
echo "DURATION=$DURATION
ACOUSTIC=$ACOUSTIC
SILENCE=$SILENCE
HIGHPERF=$HIGHPERF
STARTUP=$STARTUP
" > $HOME/.hdsgui/config

kill $XPID 2>/dev/null && exit


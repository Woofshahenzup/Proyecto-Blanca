#!/bin/bash
#
# Brightness control slider for desktop 'external' monitors - with inspiration from johnywhy, and many thanks to Fredx181
#
# detect monitor
MON=$(xrandr -q | grep " connected" | cut -f1 -d ' ')
# find current xrandr brightness value
XR=$(xrandr --verbose | grep -i brightness | cut -f2 -d ' ' | head -n1)
BrCur=`awk "BEGIN {print $XR*100}"` # calculate, so e.g. 0.5 gets 50
BrMax="100"
BrMin="10"
yad --undecorated --on-top --geometry=350x50-40-30 --text="                  Control de brillo y color de pantalla " --scale --value $BrCur --print-partial --min-value $BrMin --max-value $BrMax --button="Info":sct-info.sh --button="Noche":sct-night.sh --button="Dia":sct-day.sh --button="Hecho":1 | while read BrNew; do
# division using awk, so xrandr value gets e.g. 0.5 rather than 50
xrandr --output $MON --brightness $(awk "BEGIN {print $BrNew/100}")
done
#nilsonmorales
# GPL 3
# Simple shell script to adjust laptop LCD backlight in PuppyLinux with Samsung laptop
# Script useshttps://github.com/haikarainen/light to change the LCD backlight
# requires light-0.10b/x11/xdialog 

# Get the initial value
valor_inicial=`light -G`
 
# Set a new value
exec 3>&1
brillo_lcd=`Xdialog --title "LCD" --rangebox "Ajustar el brillo LCD"  0 0 0 100 $valor_inicial 2>&1 1>&3`
exec 3>&-

light -S $brillo_lcd
 

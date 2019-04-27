#!/bin/bash

light -S 44
yad --notification --text="Brillo y Tinte" --command='/usr/local/bin/EMBC.sh' --image='/usr/local/lib/X11/pixmaps/Bright.png' 2>/dev/null

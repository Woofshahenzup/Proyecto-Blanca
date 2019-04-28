#!/bin/sh
C="k10temp" #amd
D="coretemp" #intel
F="cpucurtemp"
G="/root/.config/"$F"/"
V="pcount"
W="/proc/cpuinfo"
Y=$(cat $W | grep -m 1 "AMD")
Z=$(cat $W | grep -m 1 "Intel")
if [ -n "$Z" ]; then
H=$(lsmod | grep -m 1 $D)
if [ -z "$H" ]; then 
modprobe $D
fi
X=$D
else
if [ -n "$Y" ]; then
H=$(lsmod | grep -m 1 $C)
if [ -z "$H" ]; then 
modprobe $C
fi
X=$C
fi
fi
T="0"
for R in {1..5}; do
S="temp"$R"_input"
P=$(sensors -u $X-* | grep $S)
Q=$(echo $P | cut -d "." -f 1 | cut -d " " -f 2)
if [[ $Q -gt $T ]]; then
T=$Q
fi
done
sleep 0.1
if [[ $T -eq "0" ]]; then
Xdialog --no-buttons --infobox "\n\n CPUCURTEMP FAILED - NO VALID MODULE" 0 0 8000
killall $F
exit
fi
echo $T > $G$F
A=$(cat $G$V)
B=$(( A+1 ))
if [[ $A -eq "720" ]]; then
echo "0" > $G$V
killall $F
exec $F
else
echo $B > $G$V
fi

#!/bin/bash
TEXTDOMAINDIR="/usr/local/share/locale/" TEXTDOMAIN=${0##*/}
# Parametros de inicio.
case "$1" in
   -n)
    DISABLETOOLTIP="true"
    export DISABLETOOLTIP
    ;;
   -*)
    printf "\n"$"Opciones"":\n\n-n   "$"Desactivar actualizaciones del tooltip \n     al conectar o desconectar unidades usb.""\n\n"
    exit
    ;;
esac

# Establecer el comando para las ventanas de información/notificación.
MSG_CMD="echo"
[ "$(which gxmessage)" ] && MSG_CMD="gxmessage -borderless -nofocus -bg black -fg white -timeout 3"
[ "$(which yaf-splash)" ] && MSG_CMD="yaf-splash -close box -timeout 3 -placement bottom-right -bg black -fg white -text"
[ -e "/usr/lib/gtkdialog/box_splash" ] && MSG_CMD="/usr/lib/gtkdialog/box_splash -close box -timeout 3 -placement bottom-right -bg black -fg white -text"
[ "$(which yad)" ] && MSG_CMD="yad --no-buttons --borders 10 --skip-taskbar --no-focus --undecorated --timeout-indicator bottom --text-align=left --timeout 5 --geometry=200x50-10-50 --text"
[ "$(which notify-send)" ] && MSG_CMD="notify-send -t 5000 -u normal"

# Debug, mostrar en CLI el software para las notificaciones.
printf "\nMSG_CMD=${MSG_CMD%%[[:blank:]]*}\n"

# yad >= 0.19
NOAPP_MSG=$"Necesitas instalar yad 0.19 o superior"
if [ "$(which yad)" ]; then
   YAD_VER="$(yad --version | cut -f 1-2 -d '.')"
   if [ $(echo "$YAD_VER >= 0.19" | bc -l) = 0 ]; then
      exec $MSG_CMD "$NOAPP_MSG"
      exit   
   fi
else
   exec $MSG_CMD "$NOAPP_MSG"
   exit
fi

# Iconos para el systray TRAY_ICON_MNT=UnMounted  TRAY_ICON_MNTD=Mounted
TRAY_ICON_MNT="/usr/local/lib/X11/pixmaps/usbdrv48.png"
TRAY_ICON_MNTD="/usr/local/lib/X11/pixmaps/usbdrv_mntd48.png"
MENU_ICON_PUPPY="/usr/share/pixmaps/puppy/puppy.svg"
MENU_ICON_MNT=list-add
MENU_ICON_MNTD=list-remove
TOOLTIP=$"Botón Izquierdo: Actualizar \nBotón Derecho: Menú"
# Sonidos al conectar y desconectar usb drives.
SND_CMD=aplay # Cambiar a "echo" para desactivar
SND_ADD="/usr/share/sounds/bark.au"
SND_REM="/usr/share/sounds/2barks.au"
ERROR_FILE="/tmp/${0##*/}_error" # Almacenar los mensajes de error del comando: mount
PIPE="/tmp/${0##*/}_tmp" # Archivo para comunicarse con yad

# Debug, mostrar algo de información.
printf "SND_CMD=$SND_CMD\nSND_ADD=$SND_ADD\nSND_REM=$SND_ADD\nERROR_FILE=$ERROR_FILE\nPIPE=$PIPE\n\n"

# Terminar script si existe "$PIPE".
[ -e "$PIPE" ] &&  echo $"Script ya está en ejecución. Saliendo..." && exit
mkfifo "$PIPE"
exec 3<> "$PIPE"

trap 'func_term' SIGINT SIGQUIT SIGTSTP EXIT

export PIPE ERROR_FILE TRAY_ICON_MNT TRAY_ICON_MNTD MENU_ICON_MNT MENU_ICON_MNTD MSG_CMD TOOLTIP

function func_term() { # Limpiar archivos temporales al cerrar el script.
   rm -f "$PIPE" "$ERROR_FILE" "/tmp/pup_event_ipc/block_${0##*/}"
   echo "quit" >&3
   exit
}

function func_menu() {
   echo $"# Generando menú #"
   exec 3<> "$PIPE"
   # Elementos adicionales para el menú.
   MENU_CMD1=$"PMount""!pmount!media-floppy"
   MENU_CMD2=$"Actualizar""!bash -c func_menu!view-refresh"
   # Resetear variables.
   unset -v MENU_MNT MENU_UMNT SEP_MNT SEP_UMNT TOOLTIPDRV MENU_DRV NUM_MNTD
   # Obtener lista de particiones sd* en formato "tamaño|nombre" ejemplo: "4194304|sdb1"
   LISTSDX=($(grep 'sd[a-z]' /proc/partitions | tr -s ' ' | tr ' ' '|' | cut -f 4-5 -d '|')) # "grep 'sd[a-z][0-9]' /proc/partitions" no detecta sdcard en garmin gps (sdb/sdc/etc.)
   # Crear lista de dispositivos de almacenamiento.
   BLOCKDEVICES=($(printf '%s\n' "${LISTSDX[@]//[[:digit:]|]/}" | sort -u))

   for BLOCKDEVICE in ${BLOCKDEVICES[@]}; do
      # Comprobar si los dispositivos de la lista son USB.
      if udevadm info -q path -n /dev/$BLOCKDEVICE | grep usb > /dev/null ; then
         if [ -z "$DISABLETOOLTIP" ]; then
            # Obtener información adicional como fabricante y modelo de la unidad.
            VENDOR=$(cat /sys/block/$BLOCKDEVICE/device/vendor | tr -s ' ')
            MODEL=$(cat /sys/block/$BLOCKDEVICE/device/model | tr -s ' ')
            # Nombre del dispositivo como encabezado de tooltip y menú, luego añadir particiones.
            # Ejemplo: Kingston DT microDuo
            TOOLTIPDRV+="<span font=\"12\"><sub><b>$VENDOR $MODEL</b></sub></span>\n"
            MENU_DRV+="|$VENDOR $MODEL"'!'"bash -c 'func_open $BLOCKDEVICE'"'!'"folder-open|"
         fi
         PARTITIONS=($(printf '%s\n' "${LISTSDX[@]}" | grep $BLOCKDEVICE))
         for PARTITION in ${PARTITIONS[@]}; do
            # Usar blkid para tomar datos de la partición.
            PARTITIONBLKID=$(blkid /dev/${PARTITION#*|})
            if [ "$PARTITIONBLKID" ]; then
               # Asignar: sistema de archivos, tamaño y etiqueta; a variables.
               PARTITIONFS=$(grep -oP 'TYPE="\K[^"]+' <<< $PARTITIONBLKID)
               PARTITIONGB=$(echo "scale=2 ; ${PARTITION%|*} / 1048576" | bc)
               PARTITIONLBL=$(grep -oP 'LABEL="\K[^"]+' <<< $PARTITIONBLKID)
               # df muestra el espacio de almacenamiento usado si la partición está montada.
               PARTITIONSPC=$(df | grep ${PARTITION#*|}[[:blank:]] | tr -s ' ' | cut -f 5-6 -d ' ' | tr ' ' '|')
               # Comprobar si la partición está montada.
               if [ "$PARTITIONSPC" ]; then
                  . /etc/DISTRO_SPECS
                  echo "${PARTITION#*|} $PARTITIONFS $PARTITIONGB GB "$"Montado" # Debug.
                  NUM_MNTD=$[NUM_MNTD + 1] # Cantidad de particiones montadas
                  # Crear un elemento para el menú. Ejemplo: "Desmontar LABEL ‣ sdb1 ‣ vfat ‣ 32 GB ‣ 50% ◔"
                  CHECK_INITRD=$(grep '/initrd/' <<< "$PARTITIONSPC")
                  if [ "$CHECK_INITRD" ] ; then
                     # Puppy boot.
                     MENU_PART="$DISTRO_NAME $DISTRO_VERSION $DISTRO_TARGETARCH ‣ $PARTITIONLBL ‣ ${PARTITION#*|} ‣ $PARTITIONFS ‣ $PARTITIONGB GB ‣ ${PARTITIONSPC%|*} ◔"'!'"bash -c 'func_open ${PARTITION#*|}'"'!'"folder-open|"
                  else
                     MENU_PART=$"Desmontar"" $PARTITIONLBL ‣ ${PARTITION#*|} ‣ $PARTITIONFS ‣ $PARTITIONGB GB ‣ ${PARTITIONSPC%|*} ◔"'!'"bash -c 'func_umount ${PARTITION#*|}'"'!'"$MENU_ICON_MNTD|"
                  fi
                  if [ -z "$DISABLETOOLTIP" ]; then
                     # Puppy boot.
                     [ "$CHECK_INITRD" ] && TOOLTIPDRVICON="◎ $DISTRO_NAME $DISTRO_VERSION $DISTRO_TARGETARCH ‣" || TOOLTIPDRVICON="⏏"
                     TOOLTIPDRV+="<sup> $TOOLTIPDRVICON $PARTITIONLBL ‣ ${PARTITION#*|} ‣ $PARTITIONFS ‣ $PARTITIONGB GB ‣ ${PARTITIONSPC%|*} ◔</sup>\n"
                     # Agregar nueva línea a MENU_DRV. Ejemplo: Kingston DT microDuo
                     #                                          Desmontar LABEL ‣ sdb1 ‣ vfat ‣ 32 GB ‣ 50% ◔
                     MENU_DRV+="$MENU_PART"
                  else
                     # Agregar esta línea a la lista de particiones desmontadas.
                     MENU_UMNT+="$MENU_PART"
                  fi
               else
                  echo "${PARTITION#*|} $PARTITIONFS $PARTITIONGB GB "$"Desmontado" # Debug.
                  MENU_PART=$"Montar"" $PARTITIONLBL ‣ ${PARTITION#*|} ‣ $PARTITIONFS ‣ $PARTITIONGB GB"'!'"bash -c 'func_mount ${PARTITION#*|} $PARTITIONFS'"'!'"$MENU_ICON_MNT|"
                  if [ -z "$DISABLETOOLTIP" ]; then
                     TOOLTIPDRV+="<sup> ⚫ $PARTITIONLBL ‣ ${PARTITION#*|} ‣ $PARTITIONFS ‣ $PARTITIONGB GB</sup>\n"
                     MENU_DRV+="$MENU_PART"
                  else
                     # Agregar esta línea a la lista de particiones montadas.
                     MENU_MNT+="$MENU_PART"
                  fi
               fi
            fi
         done
      else
         # Remover particiones de $BLOCKDEVICE si no es usb.
         LISTSDX=(${LISTSDX[@]/*$BLOCKDEVICE*})
      fi
   done
   
   # Si no existen unidades usb flash ocultar icono.
   if [ -z "$LISTSDX" ];then
      MSG_CMD_TXT=$"No se detectaron unidades usb flash, ocultando icono..."
      YADMENUBODY=""
      echo "visible:false" >&3
      echo "$MSG_CMD_TXT"
      exec ${MSG_CMD/timeout 3/timeout 5} "$MSG_CMD_TXT" &
   # Generar Menú.
   else
      echo "visible:true" >&3 
      # Cambiar icono si no hay nada montado.
      [ -z "$NUM_MNTD" ] && echo "icon:$TRAY_ICON_MNT" >&3 || echo "icon:$TRAY_ICON_MNTD" >&3
      MSG_MENU=$"# Menú generado #"

      if [ -z "$DISABLETOOLTIP" ]; then
         YADMENUBODY="$MENU_DRV"
         echo "$MENU_DRV" > /tmp/menu_drv
         echo "$MSG_MENU"
         TOOLTIPDRV+="<span font=\"1\"> </span>\n$TOOLTIP"
         echo "tooltip:$TOOLTIPDRV" >&3
         echo $"Tooltip generado."
      else
         [ "$MENU_UMNT" ] && SEP_UMNT="|"
         [ "$MENU_MNT" ] && SEP_MNT="|"
         # Remover el último caracter(separador de menú | ) de la variable ${MENU_MNT%|*}
         YADMENUBODY="$SEP_MNT${MENU_MNT%|*}$SEP_MNT$SEP_UMNT${MENU_UMNT%|*}$SEP_UMNT"
         echo "$MSG_MENU"
      fi
      # Actualizar el menú.
      echo "menu:$MENU_CMD1|$YADMENUBODY|$MENU_CMD2" >&3
   fi 
}

function func_mount() {
   mkdir -p "/mnt/$1" &
   # Montar.
   echo $"Montando /dev/$1 en /mnt/$1" &
   MOUNT_CMD="mount"
   # El script "mount" de puppy es lento para montar, usar "mount-FULL" si está disponible.
   [ "$(which mount-FULL)" ] && MOUNT_CMD="mount-FULL"
   case $2 in
      vfat)
         MOUNT_OPS="-t vfat -o iocharset=utf8,umask=000,shortname=mixed,quiet"
         eval $MOUNT_CMD "$MOUNT_OPS" "/dev/$1" "/mnt/$1" 2> "$ERROR_FILE"
         ret=$?
         ;;
      ntfs) 
         MOUNT_OPS="-t ntfs -o nls=utf8,umask=0222"
         eval $MOUNT_CMD "$MOUNT_OPS" "/dev/$1" "/mnt/$1" 2> "$ERROR_FILE"
         ret=$?
         ;;
      *)
         mount -t "$2" "/dev/$1" "/mnt/$1" 2> "$ERROR_FILE"
         ret=$?
         ;;
   esac
   # Actualizar menú.
   func_menu

   if [[ $ret -eq 0 ]]; then
      MSG_CMD_TXT=$"$1 fue montado en /mnt/$1"
      xdg-open "/mnt/$1" &
   else
      MSG_CMD_TXT=$"Error al montar /dev/$1 en /mnt/$1 código:"" $ret $(cat $ERROR_FILE)"
   fi


   echo "$MSG_CMD_TXT"
   # Agregar título a la ventana de información.
   MSG_CMD_TXT1=$"Montando"
   [ "${MSG_CMD%%[[:blank:]]*}" = "yad" ] && MSG_CMD_TXT="<b><big>$MSG_CMD_TXT1</big></b>\n$MSG_CMD_TXT"
   [ "${MSG_CMD%%[[:blank:]]*}" = "notify-send" ] && USE_MSG_CMD_TXT1="1"
   # Mostrar ventana de información.
   if [ "$USE_MSG_CMD_TXT1" ]; then
      exec $MSG_CMD "$MSG_CMD_TXT1" "$MSG_CMD_TXT"
   else
      exec $MSG_CMD "$MSG_CMD_TXT"
   fi
}

function func_umount() {
   # Desmontar.
   echo $"Desmontando /dev/$1" &
   # Determinar punto de montaje.
   MNT_DIR=$(df | grep /dev/$1[[:blank:]] | tr -s ' ' | cut -f 6 -d ' ')
   rox -D "$MNT_DIR" &
   sync
   umount "$MNT_DIR"
   ret=$?
   # Actualizar menú.
   func_menu
   
   [[ $ret -eq 0 ]] && MSG_CMD_TXT=$"$1 fue desmontado" || MSG_CMD_TXT=$"Error al desmontar $1 código:"" $ret"
   echo "$MSG_CMD_TXT"

   MSG_CMD_TXT1=$"Desmontando"
   # Agregar título a la ventana de información.
   [ "${MSG_CMD%%[[:blank:]]*}" = "yad" ] && MSG_CMD_TXT="<b><big>$MSG_CMD_TXT1</big></b>\n$MSG_CMD_TXT"
   [ "${MSG_CMD%%[[:blank:]]*}" = "notify-send" ] && USE_MSG_CMD_TXT1="1"
   # Mostrar ventana de información.
   if [ "$USE_MSG_CMD_TXT1" ]; then
      exec $MSG_CMD "$MSG_CMD_TXT1" "$MSG_CMD_TXT" &
   else
      exec $MSG_CMD "$MSG_CMD_TXT" &
   fi
}

function func_open() {
   # Determinar puntos de montaje.
   MNT_DIR=$(df | grep /dev/$1 | tr -s ' ' | cut -f 6 -d ' ')

   # Abrir carpetas.
   for MOUNTPOINT in ${MNT_DIR[@]} ; do xdg-open "$MOUNTPOINT" ; done
}

export -f func_menu func_mount func_umount func_open func_term

yad --text="$(echo -e $TOOLTIP)" --notification --command="bash -c func_menu" --image="$TRAY_ICON_MNT" --listen --no-middle <&3 &

func_menu

while true; do
   EVENTS=$(pup_event_ipc "block:${0##*/}")
   # Sonido al conectar hardware.
   [ "${EVENTS::3}" = "add" ] && exec $SND_CMD "$SND_ADD" &
   if [ "${EVENTS::3}" = "rem" ]; then
      # Sonido al desconectar hardware.
      exec $SND_CMD "$SND_REM" &
      PUPEVENTREM=($(grep -oP 'rem:\K[^ ]+' <<< $EVENTS))
      for i in ${PUPEVENTREM[@]} ; do
         # Verificar que no queden puntos de montaje activos al desconectar.
         CHECK_MNT=$(df | grep $i[[:blank:]] | tr -s ' ' | cut -f 6 -d ' ')
         if [ "$CHECK_MNT" ]; then
            # Quitar el punto de montaje dejado por el usuario al remover la unidad sin desmontar.
            func_umount $i
            MSG_CMD_TXT=$"CUIDADO, quitar la unidad $i sin desmontar puede crear pérdida de datos o dañar la unidad"
            # Agregar título a la ventana de información.
            MSG_CMD_TXT1=$"Alerta"
            [ "${MSG_CMD%%[[:blank:]]*}" = "notify-send" ] && USE_MSG_CMD_TXT1="1" && MSG_CMD="${MSG_CMD/-u normal/-u critical}"
            [ "${MSG_CMD%%[[:blank:]]*}" = "yad" ] && MSG_CMD="${MSG_CMD/--timeout 5 --geometry=200x50-10-50/--timeout 10 --geometry=200x50-10+50}" && MSG_CMD_TXT="<b><big>$MSG_CMD_TXT1</big></b>\n$MSG_CMD_TXT"

            if [ "$USE_MSG_CMD_TXT1" ]; then
               exec $MSG_CMD "$MSG_CMD_TXT1" "$MSG_CMD_TXT" &
            else
               exec ${MSG_CMD/-timeout 3 -placement bottom-right/-timeout 10 -placement top-right} "$MSG_CMD_TXT"  &
            fi
         fi
      done
   fi
   # Actualizar menu al notificar cambio de hardware.
   func_menu &
done 

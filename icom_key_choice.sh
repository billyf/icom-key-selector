#!/bin/bash

# Updates the key type for an IC-7300

RigCtl="rigctl -m 373 -r /dev/ttyUSBicom -s 19200"

# skips first lookup so the key can be changed quicker
SKIP_INITIAL_KEY_LOOKUP=1

function get_cur_key() {
	CurKeyResponseBinary=`${RigCtl} w '\0xFE\0xFE\0x94\0xE0\0x1A\0x05\0x01\0x64\0xFD'`
	echo "CurKeyResponseBinary: ${CurKeyResponseBinary}"
	CurKeyResponse=$(echo ${CurKeyResponseBinary} | xxd -p)
	echo "CurKeyResponse: ${CurKeyResponse}"
	if [ $CurKeyResponse ==   "fefe94e01a050164fdfefee0941a0501640a" ]; then
	  CurKey="Straight"
	elif [ $CurKeyResponse == "fefe94e01a050164fdfefee0941a05016401fd0a" ]; then
	  CurKey="Bug"
	elif [ $CurKeyResponse == "fefe94e01a050164fdfefee0941a05016402fd0a" ]; then
	  CurKey="Paddle"
	else
	  echo "Error getting key type, response was: ${CurKeyResponse}"
	  exit 1
	fi
	echo "#CurKey: ${CurKey}"
}

function get_cur_key_with_progress() {
	get_cur_key > >(zenity \
	  --progress \
	  --title="Key query" \
	  --text="Getting the current key type..." \
	  --auto-close \
	  --pulsate)
	echo "CurKey: ${CurKey}"
}

function get_user_selection {
	Chosen=$(zenity --info --title 'Choose your key type:' \
	      --text "Currently: ${CurKey}" \
	      --width=300 \
	      --ok-label Straight \
	      --extra-button Bug \
	      --extra-button Paddle)
	rc=$?
	echo "{$rc-$Chosen}"


	if [[ $rc == "1" ]] && [[ $Chosen == '' ]]; then
	  # they closed the dialog window
	  echo "Dialog cancelled"
	  exit 0
	elif [[ $rc == "0" ]]; then
	  Data="00"
	  # it doesn't save this above since it's the ok button
	  Chosen="Straight"
	elif [[ $Chosen == "Bug" ]]; then
	  Data="01"
	else
	  Data="02" 
	fi

	CmdStr="\0xFE\0xFE\0x94\0xE0\0x1A\0x05\0x01\0x64\0x${Data}\0xFD"

	echo "CmdStr is:"
	echo ${CmdStr}
}

function exec_update() {
	RIGCTL_ERR=$((
	  ${RigCtl} w ${CmdStr} |
	    zenity --progress \
	      --title="Setting key type" \
	      --text="Updating to ${Chosen}..." \
	      --auto-close \
	      --pulsate
	  ) 2>&1)
	echo "rigctl error: ${RIGCTL_ERR}"
	if [ -n "$RIGCTL_ERR" ]; then
	  zenity --error \
	    --width=300 \
	    --height=100 \
	    --text "Problem with rigctl command:\n${RIGCTL_ERR}"
	fi
}

# skip getting the key the first time to go faster
CurKey="(not yet queried)"
get_user_selection
exec_update
while true; do
	get_cur_key_with_progress
	get_user_selection
	exec_update
done

exit 0

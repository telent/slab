#!/usr/bin/env bash

case "$1" in
    "")
	echo "requires configuration parameter"
	exit 1
	;;
    reset)
	call-audio
	;;
    phone)
	# earpiece mic dai2
	call-audio -e -m -2
	;;
    speaker)
	# speaker mic dai2
	call-audio -s -m -2
	;;
    headset)
	# headphones headphone-mic dai2
	call-audio -h -l -2
	;;
    *)
	echo "unrecgnised configuration $1"
	exit 1
	;;
esac

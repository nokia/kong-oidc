#!/bin/sh
ADAPTER=""
if [ -z "$*" ];  then
  ADAPTER="wifi0"
else
  ADAPTER=$1
fi

ip addr show $ADAPTER | grep "inet\b" | awk '{print $2}' | cut -d/ -f1

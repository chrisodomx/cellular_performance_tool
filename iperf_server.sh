#!/bin/bash

#returns error message if no ip address for server is given

#generate log file name
date_time=$(date +"%Y-%m-%d_%H:%M:%S")
output_file="$date_time-server.log"

#echo "$date_time" | cut -d '_' -f 1,2 --output-delimiter=" " >> "$output_file"
iperf3 -s --logfile="$output_file"
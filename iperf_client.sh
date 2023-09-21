#!/bin/bash

#returns error message if no ip address for server is given
if [[ $# != 1 ]]; then
	echo "*please enter the ip address of the server*"
	exit 1
else
	server_ip="$1"
fi

#generate log file name
start_date_time=$(date +"%Y-%m-%d_%H:%M:%S")
output_file="$start_date_time-client.csv"
LOGFILE="$start_date_time-client.log"
header="Datetime,Lat.,Long.,Altitude,rssi(dbm),Transferred,Transfer(Units),Bitrate(MBytes/sec),Retr,Cwnd(KBytes)"
secs_between_tests=60

# For splitting iperf output into testing results and testing summary sections
# For point-in-time iPerf testing, we only have 1 testing interval. 
# e.g. 0.00-1.00
iperf_test_regex='[0-9]{1,6}.[0-9]{2}-[0-9]{1,6}.[0-9]{2}'

# TODO: Add this echo $date_time back after completion
#echo "$date_time" | cut -d '_' -f 1,2 --output-delimiter=" " >> "$output_file"

function check_requirements() {
	#Jcheck if jq is installed, used for parsing json
	JQ="jq"
	if ! command -v ${JQ} >/dev/null; then
  		echo "This script requires ${PROGRAM} to be installed: 'pkg install jq'"
  		exit 1
	fi
}

function get_datetime() {
	# These date/time values change throughout duration of script execution
	current_date_time=$(date +"%Y-%m-%d_%H:%M:%S")
	date=$(echo $current_date_time | cut -d '_' -f 1)
	_time=$(echo $current_date_time | cut -d '_' -f 2)

}

function get_location() {
	if [[ $OSTYPE =~ "android"* ]];then
		# Get latitude and longitude using termux on android device
		location_info=$(termux-location)
		lat=$(echo $location_info | jq '. | .latitude')
		long=$(echo $location_info | jq '. | .longitude')
		alt=$(echo $location_info | jq '.| .altitude')

		#check if latitude is empty
		if [[ -z "$lat" ]];then
			lat=0
			mylog "$location_info"
		fi 
		#check if longitude is empty
		if [[ -z "$long"]];then
			long=0
			mylog "$location_info"

		fi	
		#check if altitude is empty
		if [[ -z "$alt" ]];then
			alt=0
			mylog "$location_info"
		fi

	elif [[ $OSTYPE =~ "gnu"* ]];then
		#TODO get latitude and longitude from linux-gnu device
		
		#Set lat, long, and rssi to 0 for now
		lat=0
		long=0
		rssi=0
	fi
}

function get_rssi() { 
	if [[ $OSTYPE =~ "android"* ]];then
		### Get signal strength from UE on android device, dbm
		cellinfo_array=$(termux-telephony-cellinfo)
		#TODO: check each element in array to find 'registered: true', store that dbm in rssi
		rssi=$(echo ${cellinfo_array} | jq '.[0] | .dbm')

		#check if array is empty
		if [[ -z "$rssi" ]]; then
			#log'cellinfo_array'
			rssi=0
			mylog "$cellinfo_array"
		fi

	elif [[ $OSTYPE =~ "gnu"* ]];then
		#TODO get signal strength from linux-gnu UE
		:
	fi
}
function get_network() {
	# Re-initialize var each time to prevent contamination from previous iterations
	iperf_vars=''
	iperf_string=''

	# 10 second timeout; test a single 1 second interval; grep to only the desired line
	# e.g. [  5]   4.00-4.05   sec   275 MBytes  45.9 Mbits/sec    0   1.06 MBytes
        iperf_string=$(timeout 10 iperf3 -c $server_ip -f M -t 1 | grep -m1 -E "$iperf_test_regex")
	###DEBUG
	#iperf_string=$(timeout 10 iperf3 -c $server_ip -f M -t 1 | grep -B1 "$iperf_test_regex" | grep -v "$iperf_test_regex")
	if [[ ! -z "$iperf_string" ]]; then
		# e.g. (from example above): 275,MBytes,45.9,0,1.06
		iperf_vars=$(echo $iperf_string | tr -s ' ' | cut -d ' ' -f 5,6,7,9,10 --output-delimiter=",")
	else
		# If $iperf_vars value is not populated, likely due to timeout
		# Record failure, report this to client, continue testing
		iperf_vars="N/A - TIMEOUT,N/A - TIMEOUT,N/A - TIMEOUT,N/A - TIMEOUT,N/A - TIMEOUT"
		iperf_vars="0,0,0,0,0"
		echo "WARNING: iPerf client timed out attempting to connect to $server_ip."
	fi
}

function write_csv() {
	csv_line="$date $_time,$lat,$long,$alt,$rssi,$iperf_vars"
	###DEBUG
	#echo $csv_line
	echo $csv_line >> $output_file
}

function mylog() {
	if [[ "$LOGFILE" == "" ]];then
		echo $(date +"%Y-%m-%d %H:%M:%S: $*")
	else
		echo $(date +"%Y-%m-%d %H:%M:%S: $*") >> ${LOGFILE}
	fi
}

function main() {
	check_requirements
	echo $header >> $output_file
	while [[ 1 ]]; do
		get_datetime
		get_location
		get_rssi
		get_network
		write_csv
		sleep $secs_between_tests
	done
}

main
#!/bin/bash

# Calculate average in MB
# input: Result directory
# output: Average in MB
function calcAvg_inMB()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sed -i '/^$/d' ${LOG}
		awk '{sum+=$1} END { print "  Average =",sum/NR/1024/1024}' ${LOG} ;
	fi
}

# Calculate average in percentage
# input: Result directory
# output: Average in percentage
function calcAvg_in_p()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sed -i '/^$/d' ${LOG}
		awk '{sum+=$1} END { print " % Average =",sum/NR*100}' ${LOG} ;
	fi
}

# Calculate average
# input: Result directory
# output: Average
function calcAvg()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sed -i '/^$/d' ${LOG}
		awk '{sum+=$1} END { print "  Average =",sum/NR}' ${LOG} ;
	fi
}

#Calculate Median
# input: Result directory
# output: Median
function calcMedian()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sed -i '/^$/d' ${LOG}
		sort -n ${LOG} | awk ' { a[i++]=$1; } END { x=int((i+1)/2); if (x < (i+1)/2) print "  Median =",(a[x-1]+a[x])/2; else print "  Median =",a[x-1]; }'
	fi
}

# Calculate minimum
# input: Result directory
# output: Minimum value
function calcMin()
{
	LOG=$1
	if [ -s ${LOG} ]; then
		sed -i '/^$/d' ${LOG}
		sort -n ${LOG} | head -1
	fi
}

# Calculate maximum
# input: Result directory
# output: Maximum value
function calcMax() {
	LOG=$1
	if [ -s ${LOG} ]; then
		sed -i '/^$/d' ${LOG}
		sort -n ${LOG} | tail -1
	fi
}


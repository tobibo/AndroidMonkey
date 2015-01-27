#!/bin/bash
##### Simple shell script to start a monkey runner and save test results
##### change this values to your needs
REPORT_DIR=./reports
DAYS_TO_STORE_FILES=7
JUNIT_FILE="test_results.xml"

#Analyzing Variables
FIND_ANR="ANR in"
FIND_CRASH="CRASH"
FIND_END_OF_ERROR="System appears to have crashed"

# look for old seed, if there is a seed it means test failed before, so we use it to rerun the same events
if [ -e $REPORT_DIR/"seed.txt" ]; then
	seed=`cat $REPORT_DIR/"seed.txt"`
else
	# random for seed
    RANDOM=10
    seed=$RANDOM
	# save seed, it will be removed if test was successful
	`echo $seed > $REPORT_DIR/"seed.txt"`
fi 

#Monkey PARAMS
if [ $# -eq 2 ]; then
	THROTTLE=$1
	EVENTS_TO_INJECT=$2
else
	THROTTLE=100
	EVENTS_TO_INJECT=50000
fi
echo $WORKSPACE
if [ -d "$REPORT_DIR" ]; then
	# remove old report files
	echo "Removing old output report files..."
	find $REPORT_DIR -name '*.txt' -mtime $DAYS_TO_STORE_FILES -exec rm  {} \;
else 
	mkdir $REPORT_DIR # make dir for new report files
fi

# run monkey on the entire system
echo "Running Monkey on entire system..."
STARTED_TIMESTAMP=`date +%s`

PACKAGE = "your package" # TODO your package

# pull the log file from device?
adb shell monkey -p $PACKAGE --throttle $THROTTLE -v $EVENTS_TO_INJECT -s $seed > $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt"

# create composite report
echo "Running reports..."
from=`grep -c $FIND_CRASH $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt"`

# Create JUNIT xml file only CRASH or ANR can happen
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE

error=0
# test for crashes
if [ "$from" -gt "0" ]; then
	error=1
	END_TIMESTAMP=`date +%s`
	test_time=`expr $END_TIMESTAMP - $STARTED_TIMESTAMP`
	echo "<testsuite name=\"monkey test\" tests=\"1\" errors=\"1\" failures=\"0\" skip=\"0\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "<testcase classname=\"monkeyTest.crash_error\" name=\"path_to_test_suite.TestSomething.test_it\" time=\"$test_time\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "<error type=\"exceptions.TypeError\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "grep -n "
	from=`grep -n $FIND_CRASH $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt" | cut -f1 -d:`
	to=`grep -n "$FIND_END_OF_ERROR" $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt" | cut -f1 -d:`
	echo "To: "$to
	selection=`expr $to - $from`
	echo "Selection: "$selection
    echo "crash happend"
    echo $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt"
    echo $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
    grep -A $selection "$CRASH" $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt" | tr -d /\</ | tr -d /\>/ >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
    echo "</error>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE 
    echo "</testcase>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
    echo "</testsuite>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
fi

if [ "$error" -gt "0" ]; then
	from=`grep -c "$FIND_ANR" $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt"`
    exit 1
else
	from=0
fi


# test for anr
if [ "$from" -gt "0" ]; then
	error=1
    END_TIMESTAMP=`date +%s`
    test_time=`expr $END_TIMESTAMP - $STARTED_TIMESTAMP`
    echo "<testsuite name=\"monkey test\" tests=\"1\" errors=\"1\" failures=\"0\" skip=\"0\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "<testcase classname=\"monkeyTest.crash_anr\" name=\"monkey_runner\" time=\"$test_time\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "<error type=\"exceptions.TypeError\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
    from=`grep -n $FIND_END_OF_ERROR $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt" | cut -f1 -d:`
    to=`grep -n $FIND_END_OF_ERROR $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt" | cut -f1 -d:`
	selection=`expr $to - $from`
    echo "anr happend"
    grep -A $selection "$FIND_ANR" $REPORT_DIR/$STARTED_TIMESTAMP"_monkey_sys.txt" | tr -d /\</ | tr -d /\>/ >> $REPORT_DIR/$STARTED_TIMESTAMP"_crash_report.txt"
    echo "</error>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE 
    echo "</testcase>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
    echo "</testsuite>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
fi

if [ "$error" -gt "0" ]; then
	echo "---"
    exit 1
else
	END_TIMESTAMP=`date +%s`
	test_time=`expr $END_TIMESTAMP - $STARTED_TIMESTAMP`
	echo "<testsuite name=\"monkey test\" tests=\"1\" errors=\"0\" failures=\"0\" skip=\"0\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "<testcase classname=\"monkeyTest.success\" name=\"monkey_runner\" time=\"$test_time\">" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	echo "</testcase>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
    echo "</testsuite>" >> $REPORT_DIR/$STARTED_TIMESTAMP$JUNIT_FILE
	# delete file after test was successful
	if [ -e $REPORT_DIR/"seed.txt" ]; then
	 seed=`rm $REPORT_DIR/"seed.txt"`
	fi
fi


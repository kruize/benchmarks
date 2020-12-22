#!/bin/bash
cd $JMETER_HOME

echo jmeter -DusePureIDs=true -n -t AcmeAir.jmx -Jdrivers=$Jdrivers -Jduration=$Jduration -Jhost=$Jhost -Jport=$Jport
exec jmeter -DusePureIDs=true -n -t AcmeAir.jmx -Jdrivers=$Jdrivers -Jduration=$Jduration -Jhost=$Jhost -Jport=$Jport

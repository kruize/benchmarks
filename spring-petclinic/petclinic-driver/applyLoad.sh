#!/bin/bash
cd $JMETER_HOME

echo jmeter -n -t petclinic.jmx -j /output/petclinic.stats -JPETCLINIC_HOST=$JHOST -JPETCLINIC_PORT=$JPORT -Jduration=$JDURATION -Jusers=$JUSERS
exec jmeter -n -t petclinic.jmx -j /output/petclinic.stats -JPETCLINIC_HOST=$JHOST -JPETCLINIC_PORT=$JPORT -Jduration=$JDURATION -Jusers=$JUSERS

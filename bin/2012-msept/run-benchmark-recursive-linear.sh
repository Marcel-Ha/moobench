#!/bin/bash

#SUDOCMD="pfexec"
SUDOCMD=""
#BINDJAVA="${SUDOCMD} psrset -e 1"
BINDJAVA=""

BIN_DIR=bin/
BASE_DIR=

SLEEP_TIME=30            ## 30
NUM_LOOPS=10            ## 10
THREADS=1               ## 1
RECURSION_DEPTH=10    ## 10
TOTAL_CALLS=2000000      ## 2000000
METHOD_TIME=500000       ## 500000

TIME=`expr ${METHOD_TIME} \* ${TOTAL_CALLS} / 1000000000 \* 4 \* ${RECURSION_DEPTH} \* ${NUM_LOOPS} + ${SLEEP_TIME} \* 4 \* ${NUM_LOOPS}  \* ${RECURSION_DEPTH}`
echo "Experiment will take circa ${TIME} seconds."

# determine correct classpath separator
CPSEPCHAR=":" # default :, ; for windows
if [ ! -z "$(uname | grep -i WIN)" ]; then CPSEPCHAR=";"; fi
# echo "Classpath separator: '${CPSEPCHAR}'"

RESULTS_DIR="${BASE_DIR}/tmp/results-benchmark-recursive-linear/"
echo "Removing and recreating '${RESULTS_DIR}'"
(${SUDOCMD} rm -rf "${RESULTS_DIR}") && mkdir "${RESULTS_DIR}"
mkdir "${RESULTS_DIR}/stat"

# Clear kieker.log and initialize logging
rm -f ${BASE_DIR}/kieker.log
touch ${BASE_DIR}/kieker.log

RESULTSFN="${RESULTS_DIR}/results.csv"

JAVA_ARGS="-server"
JAVA_ARGS="${JAVA_ARGS} -d64"
JAVA_ARGS="${JAVA_ARGS} -Xms1G -Xmx1G"
JAVA_ARGS="${JAVA_ARGS} -verbose:gc -XX:+PrintCompilation"
#JAVA_ARGS="${JAVA_ARGS} -XX:+PrintInlining"
#JAVA_ARGS="${JAVA_ARGS} -XX:+UnlockDiagnosticVMOptions -XX:+LogCompilation"
#JAVA_ARGS="${JAVA_ARGS} -Djava.compiler=NONE"
JAR="-jar MooBench.jar"

JAVA_ARGS_NOINSTR="${JAVA_ARGS}"
JAVA_ARGS_LTW="${JAVA_ARGS} -javaagent:${BASE_DIR}/lib/kieker-1.9-SNAPSHOT_aspectj.jar -Dorg.aspectj.weaver.showWeaveInfo=false -Daj.weaving.verbose=false"
JAVA_ARGS_KIEKER_DEACTV="${JAVA_ARGS_LTW} -Dkieker.monitoring.adaptiveMonitoring.configFile=META-INF/kieker.monitoring.adaptiveMonitoring.disabled.conf -Dkieker.monitoring.writer=kieker.monitoring.writer.DummyWriter"
JAVA_ARGS_KIEKER_NOLOGGING="${JAVA_ARGS_LTW} -Dkieker.monitoring.writer=kieker.monitoring.writer.DummyWriter"
#JAVA_ARGS_KIEKER_LOGGING="${JAVA_ARGS_LTW} -Dkieker.monitoring.writer=kieker.monitoring.writer.filesystem.AsyncFsWriter -Dkieker.monitoring.writer.filesystem.AsyncFsWriter.customStoragePath=${BASE_DIR}/tmp"
JAVA_ARGS_KIEKER_LOGGING="${JAVA_ARGS_LTW} -Dkieker.monitoring.writer=kieker.monitoring.writer.filesystem.AsyncBinaryFsWriter -Dkieker.monitoring.writer.filesystem.AsyncBinaryFsWriter.customStoragePath=${BASE_DIR}/tmp"

## Write configuration
uname -a >${RESULTS_DIR}/configuration.txt
java ${JAVA_ARGS} -version 2 >> ${RESULTS_DIR}/configuration.txt
echo "JAVA_ARGS: ${JAVA_ARGS}" >> ${RESULTS_DIR}/configuration.txt
echo "" >> ${RESULTS_DIR}/configuration.txt
echo "Runtime: circa ${TIME} seconds" >>${RESULTS_DIR}/configuration.txt
echo "" >>${RESULTS_DIR}/configuration.txt
echo "SLEEP_TIME=${SLEEP_TIME}" >>${RESULTS_DIR}/configuration.txt
echo "NUM_LOOPS=${NUM_LOOPS}" >>${RESULTS_DIR}/configuration.txt
echo "TOTAL_CALLS=${TOTAL_CALLS}" >>${RESULTS_DIR}/configuration.txt
echo "METHOD_TIME=${METHOD_TIME}" >>${RESULTS_DIR}/configuration.txt
echo "THREADS=${THREADS}" >>${RESULTS_DIR}/configuration.txt
echo "RECURSION_DEPTH=${RECURSION_DEPTH}" >>${RESULTS_DIR}/configuration.txt
sync

## Execute Benchmark

for ((i=1;i<=${NUM_LOOPS};i+=1)); do
    echo "## Starting iteration ${i}/${NUM_LOOPS}"

    for ((j=1;j<=${RECURSION_DEPTH};j+=1)); do
        RECDEPTH=$[2**($j-1)]
        echo "# Starting recursion ${i}.${j}/${RECURSION_DEPTH}"

        # 1 No instrumentation
        echo " # ${i}.1 No instrumentation"
        mpstat 1 > ${RESULTS_DIR}/stat/mpstat-${i}-${j}-1.txt &
        vmstat 1 > ${RESULTS_DIR}/stat/vmstat-${i}-${j}-1.txt &
        iostat -xn 10 > ${RESULTS_DIR}/stat/iostat-${i}-${j}-1.txt &
        ${BINDJAVA} java  ${JAVA_ARGS_NOINSTR} ${JAR} \
            --output-filename ${RESULTSFN}-${i}-${j}-1.csv \
            --total-calls ${TOTAL_CALLS} \
            --method-time ${METHOD_TIME} \
            --total-threads ${THREADS} \
            --recursion-depth ${RECDEPTH}
        kill %mpstat
        kill %vmstat
        kill %iostat
        [ -f ${BASE_DIR}/hotspot.log ] && mv ${BASE_DIR}/hotspot.log ${RESULTS_DIR}/hotspot-${i}-${j}-1.log
        sync
        sleep ${SLEEP_TIME}

        # 2 Deactivated probe
        echo " # ${i}.2 Deactivated probe"
        mpstat 1 > ${RESULTS_DIR}/stat/mpstat-${i}-${j}-2.txt &
        vmstat 1 > ${RESULTS_DIR}/stat/vmstat-${i}-${j}-2.txt &
        iostat -xn 10 > ${RESULTS_DIR}/stat/iostat-${i}-${j}-2.txt &
        ${BINDJAVA} java  ${JAVA_ARGS_KIEKER_DEACTV} ${JAR} \
            --output-filename ${RESULTSFN}-${i}-${j}-2.csv \
            --total-calls ${TOTAL_CALLS} \
            --method-time ${METHOD_TIME} \
            --total-threads ${THREADS} \
            --recursion-depth ${RECDEPTH}
        kill %mpstat
        kill %vmstat
        kill %iostat
        [ -f ${BASE_DIR}/hotspot.log ] && mv ${BASE_DIR}/hotspot.log ${RESULTS_DIR}/hotspot-${i}-${j}-2.log
        echo >>${BASE_DIR}/kieker.log
        echo >>${BASE_DIR}/kieker.log
        sync
        sleep ${SLEEP_TIME}

        # 3 No logging
        echo " # ${i}.3 No logging (null writer)"
        mpstat 1 > ${RESULTS_DIR}/stat/mpstat-${i}-${j}-3.txt &
        vmstat 1 > ${RESULTS_DIR}/stat/vmstat-${i}-${j}-3.txt &
        iostat -xn 10 > ${RESULTS_DIR}/stat/iostat-${i}-${j}-3.txt &
        ${BINDJAVA} java  ${JAVA_ARGS_KIEKER_NOLOGGING} ${JAR} \
            --output-filename ${RESULTSFN}-${i}-${j}-3.csv \
            --total-calls ${TOTAL_CALLS} \
            --method-time ${METHOD_TIME} \
            --total-threads ${THREADS} \
            --recursion-depth ${RECDEPTH}
        kill %mpstat
        kill %vmstat
        kill %iostat
        [ -f ${BASE_DIR}/hotspot.log ] && mv ${BASE_DIR}/hotspot.log ${RESULTS_DIR}/hotspot-${i}-${j}-3.log
        echo >>${BASE_DIR}/kieker.log
        echo >>${BASE_DIR}/kieker.log
        sync
        sleep ${SLEEP_TIME}

        # 4 Logging
        echo " # ${i}.4 Logging"
        mpstat 1 > ${RESULTS_DIR}/stat/mpstat-${i}-${j}-4.txt &
        vmstat 1 > ${RESULTS_DIR}/stat/vmstat-${i}-${j}-4.txt &
        iostat -xn 10 > ${RESULTS_DIR}/stat/iostat-${i}-${j}-4.txt &
        ${BINDJAVA} java  ${JAVA_ARGS_KIEKER_LOGGING} ${JAR} \
            --output-filename ${RESULTSFN}-${i}-${j}-4.csv \
            --total-calls ${TOTAL_CALLS} \
            --method-time ${METHOD_TIME} \
            --total-threads ${THREADS} \
            --recursion-depth ${RECDEPTH}
        kill %mpstat
        kill %vmstat
        kill %iostat
        mkdir -p ${RESULTS_DIR}/kiekerlog/
        mv ${BASE_DIR}/tmp/kieker-* ${RESULTS_DIR}/kiekerlog/
        [ -f ${BASE_DIR}/hotspot.log ] && mv ${BASE_DIR}/hotspot.log ${RESULTS_DIR}/hotspot-${i}-${j}-4.log
        echo >>${BASE_DIR}/kieker.log
        echo >>${BASE_DIR}/kieker.log
        sync
        sleep ${SLEEP_TIME}
    
    done

done
tar cf ${RESULTS_DIR}/kiekerlog.tar ${RESULTS_DIR}/kiekerlog
${SUDOCMD} rm -rf ${RESULTS_DIR}/kiekerlog/
gzip -9 ${RESULTS_DIR}/kiekerlog.tar
tar cf ${RESULTS_DIR}/stat.tar ${RESULTS_DIR}/stat
rm -rf ${RESULTS_DIR}/stat/
gzip -9 ${RESULTS_DIR}/stat.tar
mv ${BASE_DIR}/kieker.log ${RESULTS_DIR}/kieker.log
[ -f ${RESULTS_DIR}/hotspot-1-1-1.log ] && grep "<task " ${RESULTS_DIR}/hotspot-*.log >${RESULTS_DIR}/log.log
[ -f ${BASE_DIR}/nohup.out ] && mv ${BASE_DIR}/nohup.out ${RESULTS_DIR}
[ -f ${BASE_DIR}/errorlog.txt ] && mv ${BASE_DIR}/errorlog.txt ${RESULTS_DIR}

# end

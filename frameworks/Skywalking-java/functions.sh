# Kieker specific functions

# ensure the script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    echo "Hey, you should source this script, not execute it!"
    exit 1
fi


function getAgent() {
	if [ ! -d "${BASE_DIR}/skywalking-agent" ] ; then
		mkdir "${BASE_DIR}/skywalking-agent"
		cd "${BASE_DIR}"
		wget https://dlcdn.apache.org/skywalking/java-agent/9.3.0/apache-skywalking-java-agent-9.3.0.tgz
		tar -xvzf apache-skywalking-java-agent-9.3.0.tgz
		cd "${BASE_DIR}"
	fi
}

function startSkywalkingServer() {
	cd "${BASE_DIR}/apache-skywalking-apm-bin/bin"
	#./startup.sh
	cd "${BASE_DIR}"
}

function stopSkywalkingServer() {
	cd "${BASE_DIR}/apache-skywalking-apm-bin"
	#./stop.sh
	echo "The server needs to be shutdonw here"
	sleep 2
	#rm -rf database/*
	#cd "${BASE_DIR}"
}



function executeBenchmark {
    for index in $MOOBENCH_CONFIGURATIONS
   	do
      	runExperiment $index
    done
}


function runExperiment {
    # No instrumentation
    k=$1
    info " # ${i}.$RECURSION_DEPTH.${k} ${TITLE[$k]}"
    if [[ "$k" -gt 0 ]]
    then
	    startSkywalkingServer
	    sleep 20
    fi
    export BENCHMARK_OPTS="${SKYWALKING_CONFIG[$k]}"
    "${MOOBENCH_BIN}" \
	--output-filename "${RAWFN}-${i}-$RECURSION_DEPTH-${k}.csv" \
        --total-calls "${TOTAL_NUM_OF_CALLS}" \
        --method-time "${METHOD_TIME}" \
        --total-threads "${THREADS}" \
        --recursion-depth "${RECURSION_DEPTH}" \
        ${MORE_PARAMS} &> "${RESULTS_DIR}/output_${i}_${RECURSION_DEPTH}_${k}.txt"
    if [[ "$k" -gt 0 ]]
    then
	    stopSkywalkingServer
    fi
}

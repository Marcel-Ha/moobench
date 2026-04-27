# Kieker specific functions

# ensure the script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "Hey, you should source this script, not execute it!"
    exit 1
fi

function getAgent() {
  if [ ! -d "${BASE_DIR}/scouter" ]; then
    mkdir "${BASE_DIR}/scouter"
    cd "${BASE_DIR}"
    wget https://github.com/scouter-project/scouter/releases/download/v2.21.3/scouter-all-2.21.3.tar.gz
    tar -xvzf scouter-all-2.21.3.tar.gz
    sed -i 's@java@java --add-opens java.base/java.lang=ALL-UNNAMED --add-exports java.base/sun.net=ALL-UNNAMED @g' "${BASE_DIR}/scouter/server/startup.sh"
    cd "${BASE_DIR}"
  fi
}

function _upsertScouterServerConfig() {
  conf_file="$1"
  key="$2"
  value="$3"

  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "${conf_file}"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "${conf_file}"
  else
    echo "${key}=${value}" >> "${conf_file}"
  fi
}

function configureScouterApi() {
  conf_file="${BASE_DIR}/scouter/server/conf/scouter.conf"
  if [ ! -f "${conf_file}" ]; then
    warn "Scouter config file missing: ${conf_file}"
    return
  fi

  _upsertScouterServerConfig "${conf_file}" "net_http_server_enabled" "true"
  _upsertScouterServerConfig "${conf_file}" "net_http_api_enabled" "true"
  _upsertScouterServerConfig "${conf_file}" "net_http_port" "${SCOUTER_API_PORT:-6180}"
  _upsertScouterServerConfig "${conf_file}" "net_http_api_allow_ips" "${SCOUTER_API_ALLOW_IPS:-localhost,127.0.0.1,0:0:0:0:0:0:0:1,::1}"
}

function startScouterServer() {
  if [ "${SCOUTER_ENABLE_API}" = "true" ]; then
    configureScouterApi
  fi

  if [ "${SCOUTER_SERVER_RUNNING}" = "true" ]; then
    debug "Scouter server already running"
    return
  fi

  cd "${BASE_DIR}/scouter/server"
  ./startup.sh
  SCOUTER_SERVER_RUNNING=true
  cd "${BASE_DIR}"
}

function stopScouterServer() {
  if [ "${SCOUTER_KEEP_SERVER_RUNNING}" = "true" ]; then
    info "Keeping Scouter server running for post-run API checks"
    return
  fi
  info "Stopping Server"
  cd "${BASE_DIR}/scouter/server"
  ./stop.sh
  sleep 2
  rm -rf database/*
  SCOUTER_SERVER_RUNNING=false
  cd "${BASE_DIR}"
}

function executeBenchmark {
    for index in $MOOBENCH_CONFIGURATIONS; do
       runExperiment $index
  done
}

function runExperiment {
    # No instrumentation
  k=$1
    info " # ${i}.$RECURSION_DEPTH.${k} ${TITLE[$k]}"
    if [[ "$k" -gt 0 ]]; then
     startScouterServer
  fi
    export SU_T_JAVA_OPTS="${SCOUTER_CONFIG[$k]}"
    "${MOOBENCH_BIN}" \
    --output-filename "${RAWFN}-${i}-$RECURSION_DEPTH-${k}.csv" \
        --total-calls "${TOTAL_NUM_OF_CALLS}" \
        --method-time "${METHOD_TIME}" \
        --total-threads "${THREADS}" \
        --recursion-depth "${RECURSION_DEPTH}" \
        ${MORE_PARAMS} &> "${RESULTS_DIR}/output_${i}_${RECURSION_DEPTH}_${k}.txt"
    if [[ "$k" -gt 0 ]]; then
     stopScouterServer
  fi
}

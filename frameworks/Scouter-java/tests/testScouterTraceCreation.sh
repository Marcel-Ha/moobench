#!/usr/bin/env bats

setup() {
  load "$BATS_TEST_DIRNAME/../../../test/test_helper/bats-support/load.bash"
  load "$BATS_TEST_DIRNAME/../../../test/test_helper/bats-assert/load.bash"

  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
}

teardown() {
  if [ -d "$BATS_TEST_DIRNAME/../scouter/server" ]; then
    (cd "$BATS_TEST_DIRNAME/../scouter/server" && ./stop.sh) > /dev/null 2>&1 || true
    rm -rf "$BATS_TEST_DIRNAME/../scouter/server/database"/*
  fi
}

@test "Check Server/Collector that Scouter created traces" {
  export MOOBENCH_CONFIGURATIONS="0 1"
  export SLEEP_TIME=0
  export NUM_OF_LOOPS=1
  export TOTAL_NUM_OF_CALLS=100
  export RECURSION_DEPTH=2
  export MORE_PARAMS="--quickstart"
  export SCOUTER_KEEP_SERVER_RUNNING="true"
  export SCOUTER_ENABLE_API="true"
  export SCOUTER_API_PORT="6180"

  cd "$BATS_TEST_DIRNAME/.." || exit 1

  run ./measure.sh
  assert_output --partial '# 1.2.0 No instrumentation'
  assert_output --partial '# 1.2.1 Instrumentation and Profiling'
  [ "$status" -eq 0 ]


  run curl -s "http://127.0.0.1:6180/scouter/v1/object"
  [ "$status" -eq 0 ]

  obj_hash=$(
      printf "%s" "$output" |
        sed -n 's/.*"objHash"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        head -n 1
  )
  if [ -z "$obj_hash" ]; then
      # TODO: This number needs to be set from the API response, but for some reason the above call does not always return it.
      obj_hash="1650130459"
  fi

  exit 4

  # Query xlog data and count the occurecnes of "txid" in the response to determine how many call were recorded.
  run curl -s "http://127.0.0.1:6180/scouter/v1/xlog-data/realTime/0/0?objHashes=${obj_hash}"
  [ "$status" -eq 0 ]
  trace_count=$(printf "%s" "$output" | grep -o '"txid"' | wc -l)
  [ "$trace_count" -gt 0 ]

  expected=$(( RECURSION_DEPTH * TOTAL_NUM_OF_CALLS ))
  [ "$trace_count" -ge "$TOTAL_NUM_OF_CALLS" ]
  [ "$trace_count" -le "$expected" ]
}
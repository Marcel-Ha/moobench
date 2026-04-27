#!/usr/bin/env bats

setup() {
  load "$BATS_TEST_DIRNAME/../../../test/test_helper/bats-support/load.bash"
  load "$BATS_TEST_DIRNAME/../../../test/test_helper/bats-assert/load.bash"

  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
}

@test "Check Skywalking OAP that Skywalking agent created traces" {
  cd "$BATS_TEST_DIRNAME/.." || exit 1
  rm -rf results-Skywalking-java/

  export SLEEP_TIME=0
  export NUM_OF_LOOPS=1 
  export TOTAL_NUM_OF_CALLS=4 
  export RECURSION_DEPTH=2
  export MOOBENCH_CONFIGURATIONS="0 1"
  export MORE_PARAMS="--quickstart"
  export SKYWALKING_KEEP_SERVER_RUNNING="true"
  exec 3>&1
  ./measure.sh 

  # Query the Skywalking CLI for the created traces and check that it is the correct number of traces.
  START=$(date -d "20 minutes ago" +"%Y-%m-%d %H%M")
  END=$(date -d "5 minutes" +"%Y-%m-%d %H%M")

  read -r -d '' QUERY <<EOF
  {
    "query": "query (\$condition: TraceQueryCondition) { queryTraces(condition: \$condition) { traces { spans { spanId } } } }",
    "variables": {
      "condition": {
        "queryDuration": {
          "start": "$START",
          "end": "$END",
          "step": "MINUTE"
        },
        "traceState": "ALL",
        "queryOrder": "BY_START_TIME",
        "paging": {
          "pageNum": 1,
          "pageSize": 100
        }
      }
    }
  }
EOF

  COUNT=$(curl -s "$OAP_URL" \
    -H 'Content-Type: application/json' \
    -d "$QUERY" \
    | jq '[.data.queryTraces.traces[].spans[]] | length')


  assert_equal "$COUNT" "8" "Expected 8 traces for 2 configs x 4 calls, but got $COUNT"

  cd results-Skywalking-java/
  count=$(ls *.csv 2>/dev/null | wc -l)
  assert_equal "$count" "0" \
    "0 .csv files should exist after the run, files should only be in the zipped folder"
  unzip results.zip 
  measuredValues=$(cat raw-1-10-* | wc -l) 
  assert_equal "$measuredValues" "8" "Expected 8 measured values for 2 configs x 4 calls x 2 recursions"
}

#!/bin/bash

# test-all.sh
# Runs all hyperdsl tests: Delite framework, Delite DSL, and Forge DSL tests
# Used by Jenkins to verify commits.

# add new DSLs to test here
dsls=( "SimpleVector" "OptiML" )
runners=( "ppl.dsl.forge.examples.SimpleVectorDSLRunner" "ppl.dsl.forge.dsls.optiml.OptiMLDSLRunner" )

# exit if any part of the script fails
set -e

# all non-Forge tests
echo "[test-all]: running Delite and Delite DSL tests (1 thread)"
sbt -Dtests.threads=1 "; project tests; test"

# and again multi-threaded
echo "[test-all]: running Delite and Delite DSL tests (8 threads)"
sbt -Dtests.threads=8 "; project tests; test"

# all Forge DSL tests
echo "[test-all]: running Forge DSL tests"

for i in `seq 0 $((${#dsls[@]}-1))` 
do  
    pushd .
    dsl=${dsls[$i]} 
    $FORGE_HOME/bin/update ${runners[$i]} $dsl 
    cd published/$dsl/
    echo "[test-all]: running $dsl tests (1 thread)"
    sbt -Dtests.threads=1 "; project $dsl-tests; test"
    echo "[test-all]: running $dsl tests (8 threads)"
    sbt -Dtests.threads=8 "; project $dsl-tests; test"
    popd
 done

echo "[test-all]: All tests finished!"

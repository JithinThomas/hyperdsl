#!/bin/bash

# build-dsl-binaries.sh
# Builds DSL binaries by running Forge and packaging up the binary results in a tarball.

# add new DSLs to package here
dsls=( "OptiML" )
runners=( "ppl.dsl.forge.dsls.optiml.OptiMLDSLRunner" )

# exit if any part of the script fails
set -e

# first we need to publish-local LMS, runtime, framework and delite-test
echo "[build binary]: publishing dependencies"
sbt "; project lms; publish-local; project runtime; publish-local; project framework; publish-local; project delite-test; publish-local"

# now build and package the DSLs
scala_version=2.10
date=`date +%Y-%m-%d`
HYPER_HOME=$PWD

pushd .

for i in `seq 0 $((${#dsls[@]}-1))` 
do  
    dsl=${dsls[$i]} 
    dsl_lower="$(echo $dsl | tr '[:upper:]' '[:lower:]')"
    dest_name=$dsl_lower-$date
    dest=$HYPER_HOME/$dest_name
    src="$HYPER_HOME/published/$dsl"

    echo "[build binary]: building DSL $dsl"
    # update won't publish the jars version of the dsl project if the local version already exists
    if [ -e "$src/project/" ]
    then
        rm -r $src/project/
    fi
    $FORGE_HOME/bin/update -j ${runners[$i]} $dsl 

    cd $src
    sbt "; project $dsl-shared; publish-local; project $dsl-lib; publish-local; project $dsl-comp; publish-local"

    echo "[build binary]: packaging binary for DSL $dsl"

    if [ -e "$dest" ]
    then
      rm -r $dest
    fi
    mkdir $dest

    # dependency jars
    mkdir $dest/lib/
    cp $src/lib_managed/jars/EPFL/lms_$scala_version/*.jar $dest/lib/
    for comp in "runtime" "framework" "delite-test"
    do
        cp $src/lib_managed/jars/stanford-ppl/$comp\_$scala_version/*.jar $dest/lib/
    done

    # dsl jars
    for comp in "shared" "library" "compiler"
    do  
        cp $src/$comp/target/scala-$scala_version/*.jar $dest/lib/
    done

    # bin
    mkdir $dest/bin/
    cp $HYPER_HOME/binary/dscripts/* $dest/bin/
    cp $HYPER_HOME/binary/sbt/* $dest/bin/
    cp $HYPER_HOME/binary/repl $dest/bin/$dsl_lower

    # sbt project
    # copy and perform on the fly name-replacement
    python $HYPER_HOME/binary/copy-and-rename.py $dsl $HYPER_HOME/binary/project/ $dest/project/

    # app src
    mkdir $dest/src/
    cp -r $src/apps/src/* $dest/src/
    mkdir $dest/test-src/
    cp -r $src/tests/src/* $dest/test-src/

    #### most of the below should be refactored in the sub-repos to be in saner places

    # datastruct folders
    mkdir -p $dest/framework/src/ppl/delite/framework/
    cp -r $HYPER_HOME/delite/framework/src/ppl/delite/framework/datastruct $dest/framework/src/ppl/delite/framework/
    mkdir -p $dest/compiler/src/$dsl_lower/compiler/
    cp -r $src/compiler/src/$dsl_lower/compiler/datastruct $dest/compiler/src/$dsl_lower/compiler/

    # config
    cp -r $HYPER_HOME/delite/config $dest/

    # runtime static
    mkdir $dest/runtime/
    for comp in "cuda" "opencl"
    do
        cp -r $HYPER_HOME/delite/runtime/$comp $dest/runtime/
    done

    # tar and cleanup
    cd $HYPER_HOME
    tar_dir=nightlies/$dsl
    mkdir -p $tar_dir
    tar -czf $tar_dir/$dest_name.tgz $dest_name
    rm -r $dest

    echo "[build binary]: finished building binary for $dsl! tarball is at: $tar_dir/$dest_name.tgz"
done

popd

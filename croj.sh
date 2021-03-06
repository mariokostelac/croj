#!/usr/bin/env bash

set -e

# detecting the directory that contains this script
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

declare work_dir=$DIR/tmp
declare src_tmp=$work_dir/src
declare bin_tmp=$work_dir/bin
declare container_base=""

# clean working dir
if [[ -d $work_dir ]]; then
  yes | rm -r $work_dir
fi
mkdir -p $work_dir

touch $work_dir/status.started

function help {
    echo 'Available commands: '
    echo
    echo 'test      - tests given code against all test cases'
    echo 'upgrade   - upgrades spoj to the newest version'
    echo 'clean     - cleans the working directory'
    echo
}

function help_test {
    echo "usage: $0 [-t <test_cases>] <tests_dir> <source_file...>"
    echo
    echo "Runs a program from given <source_filese against all the tests "
    echo "in given <tests_dir>."
    echo
    echo "-t <test_cases>:   test case indices to run, starts with 1;"
    echo "                   by default, all tests are run"
    echo
    echo "Examples:"
    echo
    echo "$0 task_1 solutions1.cpp - runs all tests"
    echo "$0 -t 1,3,4 task_1 solutions1.cpp - runs first, third and fourth tests"
    echo
}

function prepare_bin {
    if [[ -d $bin_tmp ]]; then
      yes | rm -r $bin_tmp
    fi
    mkdir -p $bin_tmp
}

function prepare_src {
    if [[ -d $src_tmp ]]; then
        yes | rm -r $src_tmp
    fi
    mkdir -p $src_tmp
    cp "$@" "$src_tmp"
}

function test_program {
    if [[ $# -lt 1 ]]; then
      help_test
      exit 1
    fi

    clean

    while getopts "ht:" opt; do
        case $opt in
            h)
                help_test
                exit 1
                ;;
            t)
                tests_to_run="$OPTARG"
                shift 2
                ;;
            ?)
                echo "todo"
                exit 1
                ;;
        esac
    done

    tests_dir=$(readlink -f $1)
    shift 1
    files=$@

    prepare_bin

    touch $work_dir/status.compiling

    # prepare and build program
    echo "Preparing the program..."
    prepare_src "$files"
    compile "$files" >> $work_dir/status.compiling 2>&1
    run_base=$container_base
    mv $bin_tmp/a.out $bin_tmp/program
    echo

    # prepare and build checker
    echo "Preparing the checker..."
    detect_checker
    prepare_src "$checker"
    compile "$checker" >> $work_dir/status.compiling.checker 2>&1
    test_base=$container_base
    mv $bin_tmp/a.out $bin_tmp/checker
    echo

    test_all $tests_dir $tests_to_run
}

function compile {
    if [[ $# -lt 1 ]]; then
        echo 'No source file given for compilation!'
        exit 1
    fi
    ext=${1##*.}
    if [[ $ext == "cpp" ]]; then
        container_base="gcc:4.8"
        build_command="g++ -O2 -std=c++11 -o /croj/tmp/bin/a.out /croj/tmp/src/*"
    elif [[ $ext == "sh" ]]; then
        # TODO: change this to something more appropriate
        container_base="gcc:4.8"
        build_command="mv /croj/tmp/src/* /croj/tmp/bin/a.out && chmod +x /croj/tmp/bin/a.out"
    else
        echo "'$ext' extension not supported"
        exit 12
    fi
    docker run --rm -v $DIR:/croj $container_base bash -c "$build_command"
}

function detect_checker {
    checker_cnt=$(find $tests_dir -name "checker.*" | wc -l)
    checker=$(find $tests_dir -name "checker.*")
    if [[ $checker_cnt -gt 1 ]]; then
        echo "Found multiple checkers: $checker"
        exit 11
    fi
    if [[ $checker_cnt -eq 0 ]]; then
        checker=$DIR/checkers/diff.sh
    fi
}

function test_all {
    test_data=$1
    tests_to_run=$2
    tester_id=$(docker run -d \
      --net=none \
      -m 128m \
      -v /communication \
      -v $DIR:/croj \
      -v "$test_data":/test_data:ro \
      $test_base ./croj/test.sh)
    docker run --rm \
      --net=none \
      --volumes-from "$tester_id" \
      -m 128m \
      $run_base ./croj/run.sh $tests_to_run
    docker kill $tester_id > /dev/null
    docker rm $tester_id > /dev/null
}

function upgrade {
    echo 'Upgrading croj to the latest version'
    cd $DIR
    git pull origin master
}

function clean {
    echo 'Cleaning working dir'
    rm -r $work_dir
    mkdir -p $work_dir
}

if [[ $# -lt 1 ]]; then
    help
    exit 1
fi

cmd=$1
shift 1

if [[ $cmd == "test" ]]; then
    test_program "$@"
elif [[ $cmd == "upgrade" ]]; then
    upgrade
elif [[ $cmd == "clean" ]]; then
    clean
else
    help
    exit 1
fi

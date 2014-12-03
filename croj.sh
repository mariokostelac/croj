#!/usr/bin/env bash

set -e

declare src_tmp=~/.croj/tmp/src
declare bin_tmp=~/.croj/tmp/bin
declare container_base=""

function help {
    echo 'Available commands: '
    echo
    echo 'get       - downloads the task(s) definitions and test cases'
    echo 'test      - tests given code against all test cases'
    echo 'upgrade   - upgrades spoj to the newest version'
    echo
}

function help_get {
    echo '#TODO'
}

function get {
    if [[ $# -lt 1 ]]; then
        help_get
        exit 1
    fi
    repo_name=$(echo $1 | cut -d/ -f1)
    repo_uri="https://github.com/mariokostelac/$repo_name/"
    echo "Pulling repo $repo_name... ($repo_uri)"
    git clone $repo_uri
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
    while getopts "t:" opt; do
        case $opt in
            t)
                tests_to_run="$OPTARG"
                shift 2
                ;;
            ?) 
                echo "todo"
                ;;
        esac
    done

    task=$1
    shift 1
    files=$@

    prepare_bin

    # prepare and build program
    prepare_src "$files"
    compile "$files"
    run_base=$container_base
    mv ~/.croj/tmp/bin/a.out ~/.croj/tmp/bin/program

    # prepare and build checker
    detect_checker
    prepare_src "$checker"
    compile "$checker"
    test_base=$container_base
    mv ~/.croj/tmp/bin/a.out ~/.croj/tmp/bin/checker

    test_all $task $tests_to_run
}

function compile {
    if [[ $# -lt 1 ]]; then
        echo 'No source file given for compilation!'
        exit 1
    fi
    ext=${1##*.}
    if [[ $ext == "cpp" ]]; then
        container_base="gcc"
        build_command="g++ /croj/tmp/src/* -o /croj/tmp/bin/a.out"
    elif [[ $ext == "sh" ]]; then
        # TODO: change this to something more appropriate
        container_base="gcc"
        build_command="mv /croj/tmp/src/* /croj/tmp/bin/a.out && chmod +x /croj/tmp/bin/a.out"
    else
        echo "'$ext' extension not supported"
        exit 12
    fi
    echo 'Compiling...'
    docker run --rm -v ~/.croj:/croj $container_base bash -c "$build_command"
    echo 'Compiled!'
}

function detect_checker {
    checker_cnt=$(find $task -name "checker.*" | wc -l)
    checker=$(find $task -name "checker.*")
    if [[ $checker_cnt -gt 1 ]]; then
        echo "Found multiple checkers: $checker"
        exit 11
    fi
    if [[ $checker_cnt -eq 0 ]]; then
        checker=~/.croj/checkers/diff.sh
    fi
}

function test_all {
    test_data=$1
    tests_to_run=$2
    tester_id=$(docker run -d -v /communication -v ~/.croj:/croj -v "$(pwd)/$test_data":/test_data $test_base ./croj/test.sh)
    docker run --rm --volumes-from "$tester_id" -v ~/.croj:/croj -v "$(pwd)/$test_data":/test_data $run_base ./croj/run.sh $tests_to_run
    docker kill $tester_id > /dev/null
    docker rm $tester_id > /dev/null
}

function upgrade {
    echo 'Upgrading croj to the latest version'
    cd ~/.croj
    git pull origin master
}

if [[ $# -lt 1 ]]; then
    help
    exit 1
fi

cmd=$1
shift 1

if [[ $cmd == "get" ]]; then
    get "$@"
elif [[ $cmd == "test" ]]; then
    test_program "$@"
elif [[ $cmd == "upgrade" ]]; then
    upgrade
else
    help
    exit 1
fi

#!/usr/bin/env bash

src_tmp=~/.croj/tmp/src
container_base=""

function help {
    echo 'Available commands: '
    echo
    echo 'get   - downloads the task(s) definitions and test cases'
    echo 'dummy - tests given code against dummy test cases'
    echo 'test  - tests given code against all test cases'
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

function prepare_src {
    if [[ ! -d $src_tmp ]]; then
        mkdir -p $src_tmp
    fi
    find $src_tmp -type f | xargs rm
    cp $@ $src_tmp
}

function dummy {
    task=$1
    shift 1
    files=$@
    prepare_src "$files"
    compile "$files"
    test_dummy $task
}

function test_program {
    task=$1
    shift 1
    files=$@
    prepare_src "$files"
    compile "$files"
    test_all $task
}

function test_dummy {
    test_data=$1
    docker run --rm -v ~/.croj:/croj -v "$(pwd)/$test_data":/test_data $container_base ./croj/test.sh dummy # 2> /dev/null
}

function test_all {
    test_data=$1
    docker run --rm -v ~/.croj:/croj -v "$(pwd)/$test_data":/test_data $container_base ./croj/test.sh # 2> /dev/null
}

function test_dummy {
    test_data=$1
    docker run --rm -v ~/.croj:/croj -v "$(pwd)/$test_data":/test_data $container_base ./croj/test.sh dummy # 2> /dev/null
}

function compile {
    if [[ $# -lt 1 ]]; then
        echo 'No source file given for compilation!'
        exit 1
    fi
    ext=${1##*.}
    if [[ $ext == "cpp" ]]; then
        container_base="gcc"
        build_command="g++ /croj/tmp/src/*.cpp -o /croj/tmp/a.out"
    elif [[ $ext == "c" ]]; then
        echo 'TODO'
        exit 1
    elif [[ $ext == "go" ]]; then
        echo 'TODO'
        exit 1
    fi
    docker run --rm -v ~/.croj:/croj $container_base bash -c "$build_command" # bash command
}

if [[ $# -lt 1 ]]; then
    help
    exit 1
fi

cmd=$1
shift 1

if [[ $cmd == "get" ]]; then
    get "$@"
elif [[ $cmd == "dummy" ]]; then
    dummy "$@"
elif [[ $cmd == "test" ]]; then
    test_program "$@"
else
    help
    exit 1
fi

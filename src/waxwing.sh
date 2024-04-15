#!/usr/bin/env bash

function waxwing::monkey_patch_commands_to_record_command_name_only() {
    for func_name in $@; do
        eval "function ${func_name}() { waxwing::write_pipe ${func_name}; }"
        export -f ${func_name}
    done
}

function waxwing::monkey_patch_commands_to_record_command_name_and_args() {
    for func_name in $@; do
        eval "function ${func_name}() { waxwing::write_pipe ${func_name} "\$@"; }"
        export -f ${func_name}
    done
}

export pipe=waxwing.pipe
function waxwing::clean_pipe() {
    command \rm -f $pipe
}

function waxwing::write_pipe() {
    if [[ ! -f $pipe ]]; then
        command \trap "waxwing::clean_pipe" INT TERM
    fi
    echo -e "${@//\\/}" >>$pipe
}

function waxwing::read_pipe() {
    contents="$(cat -v $pipe)"
    waxwing::clean_pipe
    echo -e "${contents}"
}

function waxwing::export_helper_functions() {
    export -f waxwing::monkey_patch_commands_to_record_command_name_only
    export -f waxwing::monkey_patch_commands_to_record_command_name_and_args
    export -f waxwing::clean_pipe
    export -f waxwing::write_pipe
    export -f waxwing::read_pipe
}


(
    set -euo pipefail
    NAME=waxwing


    WORKDIR=".${NAME}"
    WORKDIR_CACHE=".cache"
    FILENAME_LOG="${NAME}.log"
    FILENAME_TRACE="${NAME}.trace"


    function waxwing::__main__() {

        \mkdir -p ${WORKDIR}
        (
            local caller_dir=$(pwd)
            local workdir="$(cd ${WORKDIR} && echo $(pwd))"
            local searchdir="$(cd $@ && echo $(pwd))"

            cd ${WORKDIR}
            (
                export PATH=${caller_dir}:$PATH
                export PS4='$(basename ${BASH_SOURCE}):${LINENO}: '
                exec 3>${FILENAME_TRACE} && BASH_XTRACEFD=3

                set -euTo pipefail -o functrace
                echo "Working Path:  ${workdir}"
                echo "Search Path:   ${searchdir}"
                echo ""


                echo "Discovered Tests"
                local collection_test_files=$(waxwing::discover_test_files ${searchdir})
                for test_file in ${collection_test_files}; do
                    (
                        . ${test_file}
                        echo "    ${test_file#"${caller_dir}/"}"
                        local collection_test_names=$(waxwing::discover_test_funcs)
                        for test_name in ${collection_test_names}; do
                            echo "        ${test_name}"
                        done
                    )
                done
                echo

                for test_file in ${collection_test_files}; do
                    (
                        . ${test_file}
                        local collection_test_names=$(waxwing::discover_test_funcs)
                        for test_name in ${collection_test_names}; do
                            local shell_opts=$(set +o); [[ -o errexit ]] && shell_opts="${shell_opts}; set -e"
                            \rm -rf ${WORKDIR_CACHE}/${test_file}/${test_name}
                            mkdir -p ${WORKDIR_CACHE}/${test_file}/${test_name}
                            local return_code=0
                            set +e -xT
                            (
                                cd ${WORKDIR_CACHE}/${test_file}/${test_name}
                                waxwing::export_helper_functions
                                waxwing::clean_pipe
                                ${test_name}
                            ) >${WORKDIR_CACHE}/${test_file}/${test_name}/${test_name}.log 2>&1 || return_code=1
                            { eval "${shell_opts}";} 2> /dev/null

                            local test_id="${test_file#"${caller_dir}/"}::${test_name}"
                            if [[ $return_code == 0 ]]; then
                                printf "\e[1;32mPassed: ${test_id}\e[0m\n"
                            else
                                printf "\e[1;31mFailed: ${test_id}\e[0m\n"
                                printf "Working directory: $(pwd)\n\n"
                                set -exT
                                (
                                    cd ${WORKDIR_CACHE}/${test_file}/${test_name}
                                    waxwing::export_helper_functions
                                    waxwing::clean_pipe
                                    ${test_name}
                                ) || true
                                printf "\e[1;31mFailed: ${test_id}\e[0m\n"
                                exit 1
                            fi
                        done
                    )
                done
            ) | 2>&1 tee ${FILENAME_LOG}
        )
    }

    function waxwing::discover_test_files() {
        echo $(find $1 -type f -name "test*.sh")
    }

    function waxwing::discover_test_funcs() {
        echo $(declare -f | grep -o '^test\w*')
    }

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        waxwing::__main__ "$@"
    fi

)

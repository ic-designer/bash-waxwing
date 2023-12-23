#!/usr/bin/env bash
(
    set -euo pipefail
    __PROG__=waxwing


    __WORKDIR__=".${__PROG__}"
    __FILENAME_LOG__="${__PROG__}.log"
    __FILENAME_TRACE__="${__PROG__}.trace"


    function waxwing::__main__() {

        \mkdir -p ${__WORKDIR__}
        (
            local caller_dir=$(pwd)
            cd ${__WORKDIR__}
            (
                export PATH=${caller_dir}:$PATH
                export PS4='${BASH_SOURCE}:${LINENO}: '
                exec 3>${__FILENAME_TRACE__} && BASH_XTRACEFD=3

                set -euTo pipefail -o functrace
                echo "Working Path:  $(realpath ${caller_dir})"
                echo "Search Path:   $(realpath ${caller_dir}/${@})"
                echo ""


                echo "Discovered Tests"
                local collection_test_files=$(waxwing::discover_test_files ${caller_dir} $@)
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
                            local return_code=0
                            (
                                ${test_name} >/dev/null 2>&1
                            ) || return_code=1

                            local test_id="${test_file#"${caller_dir}/"}::${test_name}"
                            if [[ $return_code == 0 ]]; then
                                printf "\e[1;32mPassed: ${test_id}\e[0m\n"
                            else
                                printf "\e[1;31mFailed: ${test_id}\e[0m\n"
                                (
                                    set -x
                                    ${test_name}
                                )
                                exit 1
                            fi
                        done
                    )
                done

            ) | 2>&1 tee ${__FILENAME_LOG__}
        )
    }

    function waxwing::discover_test_files() {
        echo $(find $1/$2 -type f -name "test*.sh")
    }

    function waxwing::discover_test_funcs() {
        echo $(declare -f | grep -o '^test\w*')
    }

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        waxwing::__main__ "$@"
    fi

)

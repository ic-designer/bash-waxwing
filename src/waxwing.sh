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
                set -euxTo pipefail -o functrace
                echo -e "Working Path: $(realpath ${caller_dir})\n"

                echo $caller_dir/$@

                for test_file in $(waxwing::discover_test_files ${caller_dir} $@); do
                    . ${test_file}
                done

                local test_list=$(waxwing::discover_test_funcs)
                echo "Discovered Tests"
                for testname in ${test_list}; do
                    echo "    ${testname}"
                done
                echo

                for testname in ${test_list}; do
                    local return_code=0
                    (
                        ${testname} >/dev/null 2>&1
                    ) || return_code=1

                    if [[ $return_code == 0 ]]; then
                        echo -e "\e[1;32mPassed: ${testname}\e[0m"
                    else
                        echo -e "\e[1;31mFailed: ${testname}\e[0m"
                        (
                            ${testname}
                        )
                        exit 1
                    fi
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

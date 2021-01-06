#!/bin/sh
set -e

use_valgrind=true # if you disable leaks, and leave this, valgrind may find invalid memory reads / writes
valgrind_check_for_leaks=true

script_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -r "$tmp_dir"' EXIT
latc=$1
[ -z "$latc" ] && echo "Usage: $0 <path_to_latc> [TEST_DIR]..." && false

tmp_test_lat="${tmp_dir}/test.lat"
tmp_test_prog="${tmp_dir}/test"
compiler_stderr="${tmp_dir}/compiler_stderr"
prog_output="${tmp_dir}/prog_output"
valgrind_log_file="${tmp_dir}/valgrind_log"

fail() {
    # $1 -- reason
    echo -e "\033[1;31mFAILED\033[m ($1)"
    echo -e "  \033[2m${latc} ${test_lat}\033[m"
}

good_test_compilation_failed() {
    fail "compiler exited with code ${compiler_ec}, but 0 was expected"
    return 1
}
good_test_compilation_succeeded() {
    if [ "$(head -n 1 ${compiler_stderr})" != "OK" ]; then
        fail "first line of compiler's stderr is not \"OK\""
        return 1
    fi
    if ${use_valgrind}; then
        valgrind_prefix="valgrind --log-file=${valgrind_log_file} "
        if ${valgrind_check_for_leaks}; then
            valgrind_prefix="${valgrind_prefix}--leak-check=full "
        fi
    fi
    if test -f "${test_input}"; then
        ec=$(set +e; ${valgrind_prefix}${tmp_test_prog} < "${test_input}" > "${prog_output}"; echo $?)
    else
        ec=$(set +e; ${valgrind_prefix}${tmp_test_prog} < /dev/urandom > "${prog_output}"; echo $?)
    fi
    expected_ec="0"
    if test -f "${test_exit_code}"; then
        expected_ec="$(cat ${test_exit_code})"
    fi
    if [ "${ec}" != "${expected_ec}" ]; then
        fail "program exited with code ${ec}, but the expected code is ${expected_ec}"
        return 1
    fi
    if test -f "${test_output}"; then
        if ! diff "${test_output}" "${prog_output}" > /dev/null; then
            fail "program output differs from the expected output"
            return 1
        fi
    fi
    if ! tail -n 1 "${valgrind_log_file}" | grep '== ERROR SUMMARY: 0 errors' -q; then
        fail "valgrind found memory errors"
        return 1
    fi
    return 0
}
bad_test_compilation_failed() {
    if [ "$(head -n 1 ${compiler_stderr})" != "ERROR" ]; then
        fail "first line of compiler's stderr is not \"ERROR\""
        return 1
    fi
    if ! grep -qP "[Ee]rror" "${compiler_stderr}"; then
        fail "compiler's stderr does not contain error description"
        return 1
    fi
    return 0
}
bad_test_compilation_succeeded() {
    fail "compiler exited with code 0, but an error was expected"
    return 1
}
warning_test_compilation_failed() {
    fail "compiler exited with code ${compiler_ec}, but 0 was expected"
    return 1
}
warning_test_compilation_succeeded() {
    if [ "$(head -n 1 ${compiler_stderr})" != "OK" ]; then
        fail "first line of compiler's stderr is not \"OK\""
        return 1
    fi
    if ! grep -qP "[Ww]arning" "${compiler_stderr}"; then
        fail "compiler's stderr does not contain warning description"
        return 1
    fi
    return 0
}

ok_count=0
failed_count=0

test_on_dir() {
    # $1 -- dir
    abs_dir=$(cd -P -- "$1" && pwd -P)
    for test in $(find "${1}/" -type f -printf '%P\n' | sort | grep -P '\.lat$'); do
        test=${test%.lat}
        test_lat="${1}/${test}.lat"
        test_input="${1}/${test}.input"
        test_output="${1}/${test}.output"
        test_exit_code="${1}/${test}.exit_code"

        printf "%-50s " "${test}"

        if test -f "${test_output}"; then
            comp_fail=good_test_compilation_failed
            comp_succ=good_test_compilation_succeeded
            echo -n 'as good: '
        elif echo "${abs_dir}/${test}" | grep -qP '/warnings?/'; then
            comp_fail=warning_test_compilation_failed
            comp_succ=warning_test_compilation_succeeded
            echo -n 'as warn: '
        else
            comp_fail=bad_test_compilation_failed
            comp_succ=bad_test_compilation_succeeded
            echo -n 'as bad:  '
        fi

        cp "${test_lat}" "${tmp_test_lat}"
        compiler_ec=$(set +e; "${latc}" "${tmp_test_lat}" > /dev/null 2> "${compiler_stderr}"; echo $?)
        if [ "${compiler_ec}" != "0" ]; then
            func="${comp_fail}"
        else
            func="${comp_succ}"
        fi
        if "${func}"; then
            echo -e "\033[1;32mOK\033[m"
            ok_count=$((ok_count+1))
        else
            failed_count=$((failed_count+1))
        fi
    done
}


if [ "$#" == "1" ]; then
    test_on_dir "${script_dir}/"
else
    i=1
    for arg do
        if [ ${i} -ne 1 ] && [ -n "${arg}" ]; then
            test_on_dir "${arg}"
        fi
        i=$((i+1))
    done
fi

echo -e "Summary:"
echo -e "OK:\t${ok_count}"
echo -e "FAILED:\t${failed_count}"

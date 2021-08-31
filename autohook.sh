#!/usr/bin/env bash

# Autohook
# A very, very small Git hook manager with focus on automation
# Contributors:   https://github.com/Autohook/Autohook/graphs/contributors
# Version:        2.3.0
# Website:        https://github.com/Autohook/Autohook


# ANSI escape codes for colorizing output
RESTORE_COLOR="\033[0m"
BLACK="\033[0;30m"
RED="\033[00;31m"
GREEN="\033[00;32m"
YELLOW="\033[00;33m"
BLUE="\033[00;34m"
MAGENTA="\033[00;35m"
PURPLE="\033[00;35m"
CYAN="\033[00;36m"
LIGHTGRAY="\033[00;37m"
LRED="\033[01;31m"
LGREEN="\033[01;32m"
LYELLOW="\033[01;33m"
LBLUE="\033[01;34m"
LMAGENTA="\033[01;35m"
LPURPLE="\033[01;35m"
LCYAN="\033[01;36m"
WHITE="\033[01;37m"
BOLD_START=$(tput bold)
BOLD_END=$(tput sgr0)



echo() {
    builtin echo -e "[Autohook] $@";
}


# Interrupt handler for skipping the rest of the pipeline if a SIGINT is received.
sigint_handler() {
  export HOOKS_CANCELLED=true
}
trap sigint_handler SIGINT


install() {
    hook_types=(
        "applypatch-msg"
        "commit-msg"
        "post-applypatch"
        "post-checkout"
        "post-commit"
        "post-merge"
        "post-receive"
        "post-rewrite"
        "post-update"
        "pre-applypatch"
        "pre-auto-gc"
        "pre-commit"
        "pre-push"
        "pre-rebase"
        "pre-receive"
        "prepare-commit-msg"
        "update"
    )

    # installation directory for git hooks (main repo/submodule agnostic - just ensure the pwd is in
    # the right project when you call this script)
    hooks_dir="$(git rev-parse --git-path hooks)"
    # use python instead of "realpath" from coreutils because OS X doesn't come with coreutils
    # if you don't have python and have coreutils instead, you can change this ¯\_(ツ)_/¯
    this_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    for hook_type in "${hook_types[@]}"
    do
        hook_symlink="$hooks_dir/$hook_type"
        # get the relative path of this script relative to the hook file git calls
        linktarget=$(python -c "import os; print(os.path.relpath('$this_file', '$hooks_dir'))")
        ln -sf $linktarget $hook_symlink
    done
}


main() {
    calling_file=$(basename $0)

    if [[ $calling_file == "autohook.sh" ]]
    then
        command=$1
        if [[ $command == "install" ]]
        then
            install
        fi
    else
        # this repository's root (if you are installing in a submodule, this is the submodule's
        # root, not the parent module's)
        repo_root=$(git rev-parse --show-toplevel)
        hook_type=$calling_file
        symlinks_dir="$repo_root/hooks/$hook_type"
        files=("$symlinks_dir"/*)
        number_of_symlinks="${#files[@]}"
        if [[ $number_of_symlinks == 1 ]]
        then
            if [[ "$(basename ${files[0]})" == "*" ]]
            then
                number_of_symlinks=0
            fi
        fi
        echo "Looking for $hook_type scripts to run...found $number_of_symlinks!"
        if [[ $number_of_symlinks -gt 0 ]]
        then
            hook_exit_code=0
            for file in "${files[@]}"
            do
                if [ "$HOOKS_CANCELLED" = true ]; then
                  echo "Cancelled by user; not running remaining $hook_type scripts."
                  exit 1
                fi
                scriptname=$(basename $file)
                echo "BEGIN $scriptname"
                if [[ "${AUTOHOOK_QUIET-}" == '' ]]; then
                  eval "\"$file\" $@"
                else
                  eval "\"$file\" $@" &>/dev/null
                fi
                script_exit_code="$?"
                if [[ "$script_exit_code" != 0 ]]
                then
                  hook_exit_code=$script_exit_code
                  echo "${RED}${BOLD_START}FINISH $scriptname${BOLD_END}${RESTORE_COLOR}"
                else
                  echo "${GREEN}${BOLD_START}FINISH $scriptname${BOLD_END}${RESTORE_COLOR}"
                fi
            done
            if [[ $hook_exit_code != 0 ]]
            then
              echo "${RED}${BOLD_START}A $hook_type script yielded negative exit code $hook_exit_code${BOLD_END}${RESTORE_COLOR}"
              exit $hook_exit_code
            fi
        fi
    fi
}


main "$@"

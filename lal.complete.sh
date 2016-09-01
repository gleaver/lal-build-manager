# lal(1) completion

_lal()
{
    local cur prev words cword
    _init_completion || return

    local -r subcommands="build clean configure export fetch help init script run ls
                          query remove shell stash save status update update-all upgrade verify
                          publish env list-components list-dependencies list-environments"

    local has_sub
    for (( i=0; i < ${#words[@]}-1; i++ )); do
        if [[ ${words[i]} == @(build|clean|configure|export|script|fetch|help|init|remove|rm|script|run|query|shell|stash|save|status|ls|update|update-all|upgrade|verify|publish|env) ]]; then
            has_sub=1
        fi
    done

    # global flags
    if [[ $prev = 'lal' && "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W '-v -h -V --version --help' -- "$cur" ) )
        return 0
    fi
    # first subcommand
    if [[ -z "$has_sub" ]]; then
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur" ) )
        return 0
    fi

    # special subcommand completions
    local special i
    for (( i=0; i < ${#words[@]}-1; i++ )); do
        if [[ ${words[i]} == @(build|remove|rm|update|script|run|query|shell|publish|env) ]]; then
            special=${words[i]}
        fi
    done

    if [[ -n $special ]]; then
        case $special in
            build)
                # lal can get the keys from manifest.components
                local -r components=$(lal list-components)
                if [[ $prev = "build" ]]; then
                    COMPREPLY=($(compgen -W "$components" -- "$cur"))
                else
                    # suggest flags
                    local -r build_flags="-r --release -s --strict -c --config -h --help --print-only"
                    COMPREPLY=($(compgen -W "$build_flags" -- "$cur"))
                fi
                ;;
            publish)
                # lal can get the keys from manifest.components
                local -r components=$(lal list-components)
                if [[ $prev = "publish" ]]; then
                    COMPREPLY=($(compgen -W "$components" -- "$cur"))
                fi
                ;;
            env)
                local -r env_subs="set reset update help -h --help"
                if [[ $prev = "set" ]]; then
                    local -r envs="$(lal list-environments)"
                    COMPREPLY=($(compgen -W "$envs" -- "$cur"))
                else
                    COMPREPLY=($(compgen -W "$env_subs" -- "$cur"))
                fi
                ;;
            update|query)
                # Looking in local cache for allowed component names
                # Means this won't work first time, but will be quick
                local -r globals=$(find "$HOME/.lal/cache/globals/" -maxdepth 1 -mindepth 1 -type d -printf "%f " 2> /dev/null)
                COMPREPLY=($(compgen -W "$globals" -- "$cur"))
                ;;
            remove|rm)
                # look in INPUT here, nothing else makes sense
                local -r installed=$(find "$PWD/INPUT/" -maxdepth 1 -mindepth 1 -type d -printf "%f " 2> /dev/null)
                COMPREPLY=($(compgen -W "$installed" -- "$cur"))
                ;;
            shell)
                # suggest flags
                local -r sh_flags="-p --privileged -h --help --print-only"
                if [[ $prev = "shell" ]]; then
                    COMPREPLY=($(compgen -W "$sh_flags" -- "$cur"))
                fi
                ;;
            script|run)
                # locate the scripts in .lal/scripts
                local -r scripts=$(find "$PWD/.lal/scripts/" -type f -printf "%f " 2> /dev/null)
                if [[ $prev == @(script|run) ]]; then
                    COMPREPLY=($(compgen -W "$scripts" -- "$cur"))
                else
                    # Identify which script we used (arg after run)
                    local run_script i
                    for (( i=2; i < ${#words[@]}-1; i++ )); do
                        if echo "$scripts" | grep -q "${words[i]}"; then
                            run_script=${words[i]}
                        fi
                    done
                    local -r comps=$(source "$PWD/.lal/scripts/$run_script"; completer)
                    COMPREPLY=($(compgen -W "$comps" -- "$cur"))
                fi
                ;;
        esac
    fi

    return 0
} &&
complete -F _lal lal


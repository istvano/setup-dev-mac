# proxyon: set the proxy variables from the private settings file (fish).
#
# Managed by chezmoi from chezmoi/dot_config/fish/functions/proxyon.fish; the zsh version is
# ~/.config/zsh/proxy.zsh. proxy-settings validates the private file and prints the values;
# nothing here evaluates them. The first proxyon saves the previous values, unset state and
# export attributes for proxyoff.
function proxyon --description 'Set proxy variables from the private settings file'
    set -l keys http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    set -l data (command proxy-settings | string split0)
    or return 1
    test (count $data) -eq 5; and test "$data[5]" = OK; or return 1
    if not set -q __proxy_active
        for key in $keys
            if set -qx $key
                set -g __proxy_state_$key exported
            else if set -q $key
                set -g __proxy_state_$key set
            else
                set -g __proxy_state_$key unset
            end
            set -g __proxy_value_$key $$key
        end
        set -g __proxy_active 1
    end
    for index in (seq 8)
        set -gx $keys[$index] $data[(math "($index - 1) % 4 + 1")]
    end
end

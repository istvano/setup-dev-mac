# proxyoff: restore the proxy variables saved by proxyon (fish).
#
# Managed by chezmoi from chezmoi/dot_config/fish/functions/proxyoff.fish. Repeating it is
# harmless.
function proxyoff --description 'Restore the proxy variables saved by proxyon'
    set -q __proxy_active; or return 0
    for key in http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
        set -l state __proxy_state_$key
        set -l value __proxy_value_$key
        switch $$state
            case unset
                set -e $key
            case exported
                set -gx $key $$value
            case set
                set -e $key
                set -g $key $$value
        end
        set -e $state $value
    end
    set -e __proxy_active
end

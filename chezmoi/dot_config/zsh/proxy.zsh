# proxyon / proxyoff: set or clear the proxy variables from a private settings file.
#
# Managed by chezmoi from chezmoi/dot_config/zsh/proxy.zsh and sourced by ~/.zshrc; the fish
# equivalents are ~/.config/fish/functions/proxy{on,off}.fish. proxy-settings (in
# ~/.local/bin) validates the private file and prints the values; nothing here evaluates
# them. proxyon exports http_proxy, https_proxy, all_proxy and no_proxy in lower and upper
# case. The first proxyon saves the previous values, unset state and export attributes;
# proxyoff restores exactly that, and repeating either is harmless. Ported from
# setup-dev-linux-wsl (operator decision, ADR-056), whose version is itself a port of
# setup-dev-linux.

proxyon() {
  emulate -L zsh
  local key index value data
  local -a values keys
  keys=(http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY)
  for key in "${keys[@]}"; do
    if [[ ${parameters[$key]-} == *readonly* || ${parameters[$key]-} != scalar* && -v $key ]]; then
      print -u2 "proxyon: $key must be a writable scalar."
      return 1
    fi
  done
  data=$(command proxy-settings) || return 1
  values=("${(@0)data}")
  [[ ${#values} == 5 && $values[5] == OK ]] || return 1
  if [[ ${_PROXY_ACTIVE:-0} != 1 ]]; then
    typeset -gA _PROXY_VALUES=() _PROXY_TYPES=()
    for key in "${keys[@]}"; do
      _PROXY_TYPES[$key]=${parameters[$key]-unset}
      _PROXY_VALUES[$key]=${(P)key-}
    done
    typeset -g _PROXY_ACTIVE=1
  fi
  for index in {1..8}; do
    key=$keys[$index]
    value=$values[$(((index - 1) % 4 + 1))]
    typeset -gx "$key=$value"
  done
}

proxyoff() {
  emulate -L zsh
  [[ ${_PROXY_ACTIVE:-0} == 1 ]] || return 0
  local key
  for key in ${(k)_PROXY_TYPES}; do
    if [[ $_PROXY_TYPES[$key] == unset ]]; then
      unset "$key"
    else
      typeset -g "$key=$_PROXY_VALUES[$key]"
      if [[ $_PROXY_TYPES[$key] == *export* ]]; then
        typeset -gx "$key"
      else
        typeset -g +x "$key"
      fi
    fi
  done
  unset _PROXY_ACTIVE _PROXY_VALUES _PROXY_TYPES
}

#!/usr/bin/env bash
# proxy-settings validation, proxyon/proxyoff in zsh (and fish where installed) and the
# git shortcut parity between the two shells.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
source "$ROOT/tests/lib.sh"

READER="$ROOT/chezmoi/dot_local/bin/executable_proxy-settings"
ZSH_PROXY="$ROOT/chezmoi/dot_config/zsh/proxy.zsh"
ZSH_ALIASES="$ROOT/chezmoi/dot_config/zsh/git-aliases.zsh"
FISH_FUNCS="$ROOT/chezmoi/dot_config/fish/functions"
FISHRC="$ROOT/chezmoi/dot_config/fish/config.fish.tmpl"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
# The chezmoi source file is not executable in the repository; a wrapper stands in for
# the installed ~/.local/bin/proxy-settings.
printf '#!/usr/bin/env bash\nexec bash "%s" "$@"\n' "$READER" >"$tmp/bin/proxy-settings"
chmod +x "$tmp/bin/proxy-settings"
export PATH="$tmp/bin:$PATH"

fail() {
  printf 'shell-helpers test: %s\n' "$*" >&2
  exit 1
}

settings() { # file content -> private file
  printf '%s' "$2" >"$1"
  chmod 600 "$1"
}

good="$tmp/good.json"
settings "$good" '{"http_proxy":"http://proxy.example:3128","https_proxy":"http://proxy.example:3128","all_proxy":"","no_proxy":"localhost,127.0.0.1"}'

# A valid private file prints the four values, NUL-separated, then OK.
out="$(bash "$READER" "$good" | tr '\0' '|')"
[[ "$out" == 'http://proxy.example:3128|http://proxy.example:3128||localhost,127.0.0.1|OK' ]] || fail "reader output: $out"

refuse() { # label, file
  if bash "$READER" "$2" >/dev/null 2>&1; then fail "accepted: $1"; fi
}
refuse 'missing file' "$tmp/none.json"
loose="$tmp/loose.json"
settings "$loose" "$(cat "$good")"
chmod 644 "$loose"
refuse 'group/other readable' "$loose"
ln -s "$good" "$tmp/link.json"
refuse 'symlink' "$tmp/link.json"
for body in \
  '{"http_proxy":"ftp://x","https_proxy":"","all_proxy":"","no_proxy":""}' \
  '{"http_proxy":"http://","https_proxy":"","all_proxy":"","no_proxy":""}' \
  '{"http_proxy":"http://h:99999","https_proxy":"","all_proxy":"","no_proxy":""}' \
  '{"http_proxy":"","https_proxy":"","all_proxy":"","no_proxy":"","extra":""}' \
  '{"http_proxy":"","https_proxy":"","all_proxy":""}' \
  '{"http_proxy":"","http_proxy":"","https_proxy":"","all_proxy":"","no_proxy":""}' \
  '{"http_proxy":1,"https_proxy":"","all_proxy":"","no_proxy":""}' \
  '{"http_proxy":"http://h\u0007","https_proxy":"","all_proxy":"","no_proxy":""}' \
  '["http_proxy"]'; do
  settings "$tmp/bad.json" "$body"
  refuse "$body" "$tmp/bad.json"
done

# zsh: proxyon exports both cases; proxyoff restores a prior exported value and unsets
# what was unset; a failing proxyon changes nothing.
command -v zsh >/dev/null 2>&1 || fail 'zsh is required for this test.'
# shellcheck disable=SC2016 # the single-quoted program is zsh code, expanded by zsh.
zsh_out="$(PROXY_SETTINGS="$good" zsh -f -c '
  source "$1"
  export http_proxy=prior; unset HTTPS_PROXY
  proxyon; proxyon
  print -r -- "on:$http_proxy:$HTTPS_PROXY:$NO_PROXY"
  proxyoff; proxyoff
  print -r -- "off:$http_proxy:${HTTPS_PROXY-unset}:${(t)http_proxy}"
  PROXY_SETTINGS=/nonexistent proxyon 2>/dev/null; print -r -- "fail:$? ${http_proxy}"
' zsh "$ZSH_PROXY")"
expected=$'on:http://proxy.example:3128:http://proxy.example:3128:localhost,127.0.0.1\noff:prior:unset:scalar-export\nfail:1 prior'
[[ "$zsh_out" == "$expected" ]] || fail "zsh proxy round trip:"$'\n'"$zsh_out"

# fish: the same round trip. CI installs fish; a local run without it skips loudly, and
# REQUIRE_LINTERS=1 turns the skip into a failure.
if command -v fish >/dev/null 2>&1; then
  # shellcheck disable=SC2016 # the single-quoted program is fish code, expanded by fish.
  fish_out="$(PROXY_SETTINGS="$good" fish --no-config -c '
    source $argv[1]; source $argv[2]
    set -gx http_proxy prior; set -e HTTPS_PROXY
    proxyon; proxyon
    echo "on:$http_proxy:$HTTPS_PROXY:$NO_PROXY"
    proxyoff; proxyoff
    set -q HTTPS_PROXY; and set h $HTTPS_PROXY; or set h unset
    set -qx http_proxy; and set x exported; or set x local
    echo "off:$http_proxy:$h:$x"
  ' "$FISH_FUNCS/proxyon.fish" "$FISH_FUNCS/proxyoff.fish")"
  expected=$'on:http://proxy.example:3128:http://proxy.example:3128:localhost,127.0.0.1\noff:prior:unset:exported'
  [[ "$fish_out" == "$expected" ]] || fail "fish proxy round trip:"$'\n'"$fish_out"
elif [[ "${REQUIRE_LINTERS:-0}" == 1 ]]; then
  fail 'fish is required under REQUIRE_LINTERS=1.'
else
  echo 'SKIP: fish not installed; the fish proxy round trip did not run.' >&2
fi

# Git shortcuts: the zsh aliases and the fish abbreviations are the same set.
zsh_set="$(sed -nE "s/^alias ([a-z]+)='(.*)'$/\1=\2/p" "$ZSH_ALIASES" | sort)"
fish_set="$(sed -nE "s/^[[:space:]]*abbr -a ([a-z]+) '(.*)'$/\1=\2/p" "$FISHRC" | sort)"
[[ -n "$zsh_set" && "$zsh_set" == "$fish_set" ]] || {
  printf 'Git shortcuts differ between shells.\nzsh:\n%s\nfish:\n%s\n' "$zsh_set" "$fish_set" >&2
  exit 1
}
assert_match '^alias gst=' "$ZSH_ALIASES"

echo 'shell-helpers tests passed.'

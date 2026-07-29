set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

plan:
  ./bootstrap plan

setup:
  ./script/setup

verify:
  ./script/verify

test:
  ./script/test

render profiles="core,dev,ai,security,cloud,data,productivity" runtime="rancher" password_manager="bitwarden" firewall="lulu":
  ./script/render-brewfile --profiles "{{profiles}}" --runtime "{{runtime}}" --password-manager "{{password_manager}}" --firewall "{{firewall}}" --output /tmp/workstation.Brewfile
  cat /tmp/workstation.Brewfile

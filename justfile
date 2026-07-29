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

render:
  ./script/render-brewfile --output /tmp/workstation.Brewfile
  cat /tmp/workstation.Brewfile

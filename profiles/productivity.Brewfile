# Required, not optional: this workstation shares its monitors with a second Mac,
# and BetterDisplay's DDC input switching is how the displays move between them.
# DDC control and input switching are free-tier features. See ADR-007.
cask "betterdisplay" # Free native display manager: HiDPI, DDC brightness and monitor input switching.

# Moved here from productivity-extra, so it installs by default rather than on request.
#
# It is the one non-development application on this machine that holds work rather than
# displaying it: notes, decisions and the reasoning behind them. A new Mac without it is
# missing something the operator uses every day, and the whole point of this repository is
# that a new Mac is usable the same afternoon.
#
# Local Markdown files on disk, which is why it qualifies where Notion and Linear did not
# (ADR-028): there is no Electron-wrapped web app here that the isolated browser contexts
# could serve instead, and no account required to read your own notes.
cask "obsidian" # Local-file Markdown knowledge base. Notes live as plain files on disk.

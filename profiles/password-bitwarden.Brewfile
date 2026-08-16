cask "bitwarden" # Free native password manager with browser integration.
# The CLI is what makes a new machine recoverable rather than merely reinstallable. The age
# identity is restored from the vault by run_once_after_15 and by script/identity --restore;
# without `bw` that hook can only mint a fresh identity, and files encrypted to the previous
# one become unreadable. The desktop app cannot be scripted, so the cask alone is not enough.
brew "bitwarden-cli" # Reads the age identity out of the vault during setup.

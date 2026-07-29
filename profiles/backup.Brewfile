# Encrypted, deduplicating backup. Host placement is required: these tools must
# read the real home directory and reach external and off-site storage, which a
# project container deliberately cannot do.
#
# This profile supplements encrypted Time Machine, it does not replace it.
# See docs/OPERATIONS.md for repository initialisation, the exclusion set, the
# restore drill and where the repository password is kept.
brew "restic" # Client-side encrypted, deduplicating, verifiable backup repositories.
brew "rclone" # Transport to the off-site object-storage backend restic writes to.

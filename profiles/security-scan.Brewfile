# Single-binary scanners kept on the host for interactive, ad-hoc inspection.
#
# ADR-010 keeps repeatable, CI-equivalent scanning inside each project's own
# containers, and that remains the rule for pipelines. ADR-015 permits these
# specific tools on the host as well because each is a single static binary with
# no daemon, no persistent state and no privileged access, and because the
# interactive use case is inspecting an artefact before deciding to trust it.
#
# Use the project's containerised scanners for anything reproducible.
brew "trivy"        # Filesystem, image and IaC vulnerability and misconfiguration scanner.
brew "syft"         # Generates an SBOM for an image, directory or archive.
brew "grype"        # Matches an SBOM or image against vulnerability data.
brew "osv-scanner"  # Checks lockfiles against the OSV vulnerability database.
brew "trufflehog"   # Verifies discovered credentials rather than only pattern-matching them.
brew "hadolint"     # Dockerfile linter used while authoring project images.
brew "dive"         # Inspects container image layers and wasted space.

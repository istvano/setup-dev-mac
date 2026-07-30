# Authoring and diagramming, for the product side of the work.
#
# Diagrams-as-code is preferred over binary drawing files: a .d2 source reviews
# in a pull request and survives the tool that produced it, which a proprietary
# canvas does not.
brew "d2"     # Declarative diagram language producing SVG/PNG from versionable source.
brew "pandoc" # Converts Markdown to docx, pdf and slides for stakeholders.

# drawio self-updates outside `brew upgrade` and ./script/update-report, so it
# does not pass through the reviewed update flow.
cask "drawio"  # Offline GUI diagram editor for work that is not diagrams-as-code.

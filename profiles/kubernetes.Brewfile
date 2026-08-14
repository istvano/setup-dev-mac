brew "kubernetes-cli" # Kubernetes control-plane client (kubectl) for interactive host use.
brew "helm"    # Kubernetes package and release manager for interactive host use.
brew "k9s"     # Terminal UI for interactive Kubernetes operations.
brew "kubectx" # Fast Kubernetes context and namespace switching.
brew "stern"   # Concurrent host-side log tailing across Kubernetes pods.
# Two local-cluster tools, which ADR-022 normally forbids. The overlap is
# deliberate and recorded in ADR-037: they answer different questions.
#
#   k3d  runs k3s, which is what a single-machine cluster should be — Traefik,
#        ServiceLB and metrics-server included, fast to create and destroy. This is
#        the daily driver.
#   kind runs upstream Kubernetes, which is what a managed cloud cluster is. It is
#        the parity tool for a project whose production target is EKS, GKE or AKS.
#
# Neither substitutes for the other, and choosing by production target is the
# reason to keep both rather than drift.
brew "k3d"         # Runs k3s clusters in containers on the selected runtime.
brew "kind"        # Runs upstream Kubernetes clusters, for managed-cloud parity.
brew "kubeconform" # Validates manifests against Kubernetes schemas without cluster access.
brew "krew"        # Plugin manager for kubectl.

# GitOps and manifest handling for remote clusters. All single static binaries.
# popeye was evaluated and rejected under ADR-026: last released January 2025.
brew "argocd"    # CLI for Argo CD: app sync, diff and rollback against remote clusters.
brew "kustomize" # Standalone overlay rendering, for pipelines that cannot rely on kubectl -k.
brew "helmfile"  # Declares and reconciles many Helm releases as one desired state.
brew "kubeseal"  # Encrypts secrets to SealedSecrets so manifests are safe to commit.

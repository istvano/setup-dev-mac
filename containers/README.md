# Container services

PostgreSQL/pgvector, Redis, Qdrant, MLflow and scanner wrappers are containerised.
Ports bind to loopback, databases use named volumes, repositories mount read-only,
the Docker socket is never mounted and images are resolved to immutable digests.

Prowler AWS runs only with explicitly exported short-lived credentials; the wrapper does not mount `~/.aws`.

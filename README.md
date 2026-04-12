# Replication in PostgreSQL

## Introduction

This project is a proof-of-concept to explore replication in distributed data stores using PostgreSQL as an example.
It explores logical replication — where a primary node publishes changes and replica nodes subscribe to receive them —
demonstrating how data can be kept in sync across multiple PostgreSQL instances.

## What the Project is About

The setup consists of one primary PostgreSQL node and two read replicas, all running in Docker containers:

- **Primary** — accepts writes, runs a publication (`mypub`) that broadcasts all table changes
- **Replica 1** — subscribes to the primary via subscription `mysub1`
- **Replica 2** — subscribes to the primary via subscription `mysub2`

Any data written to the primary is automatically replicated to both replicas through PostgreSQL's logical replication mechanism.

```
          writes
client ─────────► primary (mypub)
                     │
           ┌─────────┴─────────┐
           ▼                   ▼
       replica1             replica2
       (mysub1)             (mysub2)
```

## Initialize Project

Clone the repository and ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

No additional setup is required. All initialization scripts run automatically when the containers start.

## Starting Up Infrastructure

```bash
docker compose up -d
```

This will:

1. Start the primary and wait until it passes its health check
2. Start both replicas once the primary is healthy
3. Run init scripts that create the replication user, publication, and subscriptions automatically

To follow the logs:

```bash
docker compose logs -f
```

To verify replication is active, connect to the primary and check publication status:

> **Warning:** This setup and the commands below are for demonstration and development only. Do not use this configuration or these scripts in production environments without further hardening and security review.

```bash
# Show replication status in terminal
docker exec -it primary psql -U postgres -d mydb -c "SELECT * FROM pg_stat_replication;"

# Or pipe the output to a file on the host (remove -it for clean output):
docker exec primary psql -U postgres -d mydb -c "SELECT * FROM pg_stat_replication;" > replication_status.txt
```

To verify subscriptions on a replica:

```bash
docker exec -it replica1 psql -U postgres -d mydb -c "SELECT * FROM pg_stat_subscription;"
```

## Destroying Infrastructure

To stop and remove containers while preserving data volumes:

```bash
docker compose down
```

To stop and remove containers **and** delete all data volumes:

```bash
docker compose down -v
```

Use `-v` when you want a clean slate — for example, before re-running the initialization scripts from scratch.

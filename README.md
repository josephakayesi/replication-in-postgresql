# Replication in PostgreSQL

## Introduction

This project is a proof-of-concept to explore replication in distributed data stores using PostgreSQL as an example.
It covers two replication strategies — logical replication and streaming replication — demonstrating how each works
and how data can be kept in sync across multiple PostgreSQL instances.

## What the Project is About

The project runs two independent clusters side by side, one per replication type.

### Logical Replication

The primary publishes all table changes via a publication. Each replica subscribes independently and receives row-level changes.

- **logical-primary** — accepts writes, broadcasts changes via publication `mypub`
- **logical-replica-1** — subscribes via `mysub1`
- **logical-replica-2** — subscribes via `mysub2`

```
          writes
client ─────────► logical-primary (mypub)
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
    logical-replica-1       logical-replica-2
       (mysub1)                 (mysub2)
```

### Streaming Replication

The primary streams WAL (Write-Ahead Log) continuously. Each replica clones the primary via `pg_basebackup` on first start and then stays in sync by consuming the WAL stream.

- **streaming-primary** — accepts writes, streams WAL to standbys
- **streaming-replica-1** — physical hot standby
- **streaming-replica-2** — physical hot standby

```
          writes
client ─────────► streaming-primary
                        │  WAL stream
            ┌───────────┴───────────┐
            ▼                       ▼
   streaming-replica-1    streaming-replica-2
```

## Project Structure

```
configs/
  logical/            postgresql.conf (wal_level = logical) + pg_hba.conf
  streaming/          postgresql.conf (wal_level = replica) + pg_hba.conf

init/
  logical/            init-primary.sql  — creates replication role + publication
  streaming/          init-primary.sql  — creates replication role

replica-init/
  logical/            init-replica-1.sql, init-replica-2.sql  — CREATE SUBSCRIPTION
  streaming/          replica-entrypoint.sh  — pg_basebackup + standby startup

docker-compose.logical.yml    logical replication cluster
docker-compose.streaming.yml  streaming replication cluster
Taskfile.yml                  task runner for both clusters
```

## Initialize Project

Clone the repository and ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Task](https://taskfile.dev/installation/) — task runner used to manage both clusters

No additional setup is required. All initialization scripts run automatically when the containers start.

## Starting Up Infrastructure

Use `task` to manage each cluster independently or both at once.

### Logical replication cluster

```bash
task up:logical
```

This will:

1. Start `logical-primary` and wait until it passes its health check
2. Start `logical-replica-1` and `logical-replica-2` once the primary is healthy
3. Run init scripts that create the replication role, publication, and subscriptions automatically

### Streaming replication cluster

```bash
task up:streaming
```

This will:

1. Start `streaming-primary` and wait until it passes its health check
2. Start `streaming-replica-1` and `streaming-replica-2` once the primary is healthy
3. Each replica runs `pg_basebackup` to clone the primary, then starts in standby mode

### Both clusters

```bash
task up
```

### Follow logs

```bash
# Logical
docker compose -f docker-compose.logical.yml logs -f

# Streaming
docker compose -f docker-compose.streaming.yml logs -f
```

## Verifying Replication

> **Warning:** This setup is for demonstration and development only. Do not use this configuration in production without further hardening and security review.

### Logical — check subscriptions on a replica

```bash
docker exec -it logical-replica-1 psql -U postgres -d mydb -c "SELECT * FROM pg_stat_subscription;"
```

### Streaming — check connected standbys on the primary

```bash
docker exec -it streaming-primary psql -U postgres -d mydb -c "SELECT * FROM pg_stat_replication;"
```

### Streaming — check standby status on a replica

```bash
docker exec -it streaming-replica-1 psql -U postgres -d mydb -c "SELECT * FROM pg_stat_wal_receiver;"
```

## Destroying Infrastructure

| Command                | Effect                                 |
| ---------------------- | -------------------------------------- |
| `task down:logical`    | Stop logical cluster, keep volumes     |
| `task clean:logical`   | Stop logical cluster, delete volumes   |
| `task down:streaming`  | Stop streaming cluster, keep volumes   |
| `task clean:streaming` | Stop streaming cluster, delete volumes |
| `task down`            | Stop both clusters, keep volumes       |
| `task clean`           | Stop both clusters, delete all volumes |

Use `clean` when you want a fresh start — for example, before re-running initialization scripts from scratch.

## Deep dive

- Postgres uses WAL (Write-Ahead Logs) to keep track of data changes
- An LSN (Log Sequence Number) tells Postgres exactly which point in the WAL logs replication has reached.

PostgreSQL is a memory-first database: reads come from shared buffers (even if disk is outdated), writes update memory first, WAL guarantees durability, and disk is updated later for persistence and recovery.

## Dynamo Failure Detection

Because membership changes are explicitly controlled by an administrator, failure detection in Dynamo is intentionally lightweight and decentralized. Nodes use gossip-based peer communication to detect unreachability, and failures are treated as temporary suspicions rather than immediate removals, since network partitions and transient outages are expected.

-- Create replication user and publication on primary
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'rep_pass';
GRANT ALL PRIVILEGES ON DATABASE mydb TO replicator;
CREATE PUBLICATION mypub FOR ALL TABLES;

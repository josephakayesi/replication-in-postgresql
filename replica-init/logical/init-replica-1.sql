-- Create subscription on replica 1
CREATE SUBSCRIPTION mysub1
  CONNECTION 'host=logical-primary port=5432 user=replicator password=rep_pass dbname=mydb'
  PUBLICATION mypub;

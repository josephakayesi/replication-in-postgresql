-- Create subscription on replica 2
CREATE SUBSCRIPTION mysub2
  CONNECTION 'host=primary port=5432 user=replicator password=rep_pass dbname=mydb'
  PUBLICATION mypub;

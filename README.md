WIP

cp-rest-admin - topic, RBAC, quota management via Ansible and CP REST API (and in some cases via commandline) 

Right now only supports REST endpoint with Basic AUTH

Works, RBAC, Quota - topics management using configuration structure in a declarative manner

Partitions increase done via kafka-topics command line too as it is yet to be supported in REST API v3

RBAC - works only with clusters registered in the Cluster Registry (too lazy to add additional handing of combined cluster scopes)

Quotas - only via kafka-configs; again REST API support is not yet available

TODO - testing, better readme, updating once the REST API availability is there for the missing features
TODO - add RBAC principal blacklist (protected accounts) and whitelist
TODO - extend quota management to principals

Works with Ansible 2.9+ 

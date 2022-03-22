cp-rest-admin - topic management via Ansible and CP REST API

Right now only supports REST endpoint with Basic AUTH

Works - topics management using topics structure in a declarative manner

Partitions increase done via kafka-topics command line too as it is yet to be supported in REST API v3

RBAC - works only with clusters registered in the Cluster Registry (too lazy to add additional handing of combined cluster scopes)

Quotas - only via kafka-configs; again REST API support is not yet available

TODO - testing, possibly renaming this project, updating once the REST API availability is there for the missing features
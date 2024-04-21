Use Cases Supported:
1. Topic Management for both new and existing clusters (after performing the initial dump of the current state)
    - done using REST API of the Confluent Server
    - CLI required only for the number of partitions increase (REST API support not available in the Confluent REST API yet)
    - Authentication using Basic Auth
2. RBAC Management for both new and existing clusters (after performing the initial dump of the current state)
    - done using REST API of the Confluent MDS Server
    - Authentication using Basic Auth
    - requires all managed clusters to be registered in the Cluster Registry
3. Quota Management for both new and existing clusters (after performing the initial dump of the current state)
    - 100% CLI implementation (REST API support not available in the Confluent REST API yet)
4. Zookeeper ACL Management for both new and existing clusters (after performing the initial dump of the current state)
    - done using REST API of the Confluent Server
    - Authentication using Basic Auth
5. Centralize ACL Management for both new and existing clusters (after performing the initial dump of the current state)
    - done using REST API of the Confluent MDS Server
    - Authentication using Basic Auth
6. Schema Management provides ability to register new schemas, delete current and all previous versions of schema, update compatibility
   backup schema and restore schemas to a new cluser (after performing the initial dump of the current state)
   Supports all format types AVRO, PROTOBUF & JSON; Different subject scopes @topic level, @record level @ topic record level
    - Authentication using Basic Auth      

All playbooks support dumping the initial state to a file by enabling the following variables (and their alternatives for quota and rbac management):
    topic_dump_file: true
    topic_dump_destination: /tmp/topic_dump_out.yml    

All playbooks allow for evaluating the impact of the input changes using the Ansible check mode (verbosity level 2 gives the output structures/build plans)
    ansible-playbook -i hosts_test.yml topics_management.yml --check -vv

The execution of the playbooks after checking the execution plan 
    ansible-playbook -i hosts_test.yml topics_management.yml

Notable variables in the inventory (refer to the sample file)    

# REST API connectivity for topics management
    rest_server_url: https://kafka1.confluent.io:8090
    rest_user: user
    rest_user_password: user-secret

# For topics management get cluster id >confluent cluster describe --url https://url:<port> -ojson | jq -r '.crn'      
    cluster_id: - note that this is optional now and gets populated from the metadata endpoint automatically if not filled
# properties for Kafka command line use - needed only for partitions_count increase and quota management     
    kafka_broker_hostname: kafka1.confluent.io
    kafka_broker_port: 9091
# add configuration file details for client connectivity to the cluster    
    kafka_broker_client_config_file: ./settings/client.properties

# provide secrets protection key if applicable    
    secrets_protection_masterkey: blahblah
# path to binaries    
    binary_base_path: /home/confluent/confluent-7.0.1    

# topics delete is disabled by default
    topic_delete_enabled: false
# partitions management disabled by default
    topic_partitions_enabled: false

# list regex representing all topics you want to be left alone
    topic_protected: ^_confluent.*|^connect.*|^ksql.*|_schemas|^confluent.*

# sample desired topics state structure - can be managed using external file
    topics:
      - topic_name: test
        partitions_count: 6
        replication_factor: 3
        configs:
          - name: min.insync.replicas
            value: "2"
      - topic_name: test2
        partitions_count: 6
        replication_factor: 3
        configs:
          - name: min.insync.replicas
            value: "1"
          - name: retention.ms
            value: "60480000"

# rbac section
# connectivity for the MDS connection - the user must be SystemAdmin 
    mds_user: mds
    mds_user_password: mds
    mds_server_url: https://kafka1.confluent.io:8090

# sample desired rolebindings state configuration - can be managed in an external file
    rolebindings:
    - clusterName: test-cluster
      name: test-cluster-0
      principal: User:connectAdmin
      resources:
      - name: _confluent-monitoring
        patternType: PREFIXED
        resourceType: Topic
      role: DeveloperWrite
    - clusterName: test-cluster
      name: test-cluster-1
      principal: User:connectAdmin
      resources:
      - name: operator.connect
        patternType: LITERAL
        resourceType: Group
      - name: operator.connect-
        patternType: PREFIXED
        resourceType: Topic
      role: ResourceOwner
    - clusterName: test-cluster
      name: test-cluster-2
      principal: User:ksqlDBAdmin
      resources:
      - name: kafka-cluster
        patternType: LITERAL
        resourceType: Cluster
      - name: operator.ksqldb_
        patternType: PREFIXED
        resourceType: TransactionalId
      role: DeveloperWrite
    - clusterName: test-cluster
      name: test-cluster-3
      principal: User:ksqlDBAdmin
      resources:
      - name: _confluent-ksql-operator.ksqldb_
        patternType: PREFIXED
        resourceType: Group
      - name: _confluent-ksql-operator.ksqldb__command_topic
        patternType: LITERAL
        resourceType: Topic
      - name: operator.ksqldb_ksql_processing_log
        patternType: LITERAL
        resourceType: Topic
      role: ResourceOwner
    - clusterName: test-cluster
      name: test-cluster-4
      principal: User:schemaregistryUser
      resources:
      - name: id_schemaregistry_operator
        patternType: LITERAL
        resourceType: Group
      - name: _confluent-license
        patternType: LITERAL
        resourceType: Topic
      - name: _schemas_schemaregistry_operator
        patternType: LITERAL
        resourceType: Topic
      role: ResourceOwner
    - clusterName: test-cluster
      name: test-cluster-5
      principal: User:controlcenterAdmin
      role: SystemAdmin
    - clusterName: test-cluster
      name: test-cluster-6
      principal: User:superUser
      role: SystemAdmin
    - name: test-cluster-7
      clusterName: test-cluster
      principal: User:alice
      resources:
      - name: test
        patternType: PREFIXED
        resourceType: Topic
      # - name: test
      #   patternType: PREFIXED
      #   resourceType: Group
      role: ResourceOwner
    - name: test-cluster-8
      clusterName: test-cluster
      principal: User:bob
      role: SystemAdmin
# define accounts protected from management    
    rbac_protected_accounts: "User:superUser"
# regex to limit the clusters managed with this playbook
    rbac_cluster_whitelist: ".*"

# to only apply the rolebindings (delete operation will be bypassed) defined in the input file set the following (default is true)
this can be used to apply the rolebindings to a new cluster without deleting the existing ones - e.g. when applying select rolebindings from a different cluster 

    rbac_delete_enabled: false

# quotas management connectivity defined above

## to only apply the quotas (delete operation will be bypassed) defined in the input file set the following (default is true)
    quotas_delete_enabled: false
# sample desired quotas state structure
    quotas:
      clients:  
        - clients: test
          consumer_byte_rate: 100002.0
          producer_byte_rate: 100001.0
          # request_percentage: 30.0
        # - client_id: test2
        #   consumer_byte_rate: 100002.0
        #   producer_byte_rate: 100001.0
        - clients: test3
          consumer_byte_rate: 100003.0
          producer_byte_rate: 100003.0
          request_percentage: 20.0
        - clients: test4
          consumer_byte_rate: 100004.0
          producer_byte_rate: 100004.0
          request_percentage: 20.0
        - clients: default
          consumer_byte_rate: 100004.0
          producer_byte_rate: 100004.0
          request_percentage: 20.0
      users:          
        - users: test
          consumer_byte_rate: 100002.0
          producer_byte_rate: 100001.0
          request_percentage: 20.0
        # - users: test2
        #   consumer_byte_rate: 100002.0
        #   producer_byte_rate: 100001.0
        #   request_percentage: 22.0
        - users: test3
          consumer_byte_rate: 100003.0
          producer_byte_rate: 100003.0
          request_percentage: 23.0
          clients:
            - clients: test
              consumer_byte_rate: 100001.0
              producer_byte_rate: 100001.0
              request_percentage: 21.0
            - clients: test2
              consumer_byte_rate: 100002.0
              producer_byte_rate: 100002.0
              request_percentage: 23.0
            # - clients: test3
            #   consumer_byte_rate: 100003.0
            #   producer_byte_rate: 100003.0
            #   request_percentage: 23.0
        - users: default
          consumer_byte_rate: 100002.0
          producer_byte_rate: 100001.0
          request_percentage: 20.0
          clients:
            - clients: test
              consumer_byte_rate: 100001.0
              producer_byte_rate: 100001.0
              request_percentage: 21.0

# Zookeeper ACLs management connectivity defined above - note Zookeeper ACLs do not use cluster registry - must use Kafka Cluster ID
# sample desired ACL state structure
    zacls:
    - patterns:
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: bobtest
        resource_type: GROUP
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: bobtest
        resource_type: TOPIC
      principal: User:Bob
    - patterns:
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        - host: '*'
          operation: WRITE
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: test
        resource_type: GROUP
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: test
        resource_type: TOPIC
      principal: User:alice

# Centralized ACLs management connectivity defined above - note Centralized ACLs do not use cluster registry - must use Kafka Cluster ID
# sample desired ACL state structure
    cacls:
    - patterns:
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: bobtest
        resource_type: GROUP
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: bobtest
        resource_type: TOPIC
      principal: User:Bob
    - patterns:
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        - host: '*'
          operation: WRITE
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: test
        resource_type: GROUP
      - entries:
        - host: '*'
          operation: READ
          permission: ALLOW
        pattern_type: PREFIXED
        resource_name: test
        resource_type: TOPIC
      principal: User:alice

# Usage

## Common

### Verify the execution plan without applying it - dry-run
ansible-playbook -i inventory.yml -e @vars.yml --check resource_specific_playbook.yml
### Verify the execution plan without applying it - dry-run, print the plan
ansible-playbook -i inventory.yml -e @vars.yml --check resource_specific_playbook.yml -vv

## Topics

### Dry-run
ansible-playbook -i hosts_test.yml topics_management.yml  -vv --check
### Apply 
ansible-playbook -i hosts_test.yml topics_management.yml

## Rolebindings

### Dry-run
ansible-playbook -i hosts_test.yml rbac_management.yml  -vv --check
### Apply 
ansible-playbook -i hosts_test.yml rbac_management.yml

## Quotas

### Dry-run
ansible-playbook -i hosts_test.yml quota_management.yml  -vv --check
### Apply 
ansible-playbook -i hosts_test.yml quota_management.yml

## Zookeeper ACLs
### Dry-run
ansible-playbook -i hosts_test.yml zacl_management.yml  -vv --check
### Apply 
ansible-playbook -i hosts_test.yml zacl_management.yml

## Centralized ACLs

### Dry-run
ansible-playbook -i hosts_test.yml cacl_management.yml  -vv --check
### Apply 
ansible-playbook -i hosts_test.yml cacl_management.yml

# sample desired Comprehensive Schema state configuration - can be managed in an external file

schemas: <br>
       record_schemas: <br>
         - record_name: "com.mycorp.mynamespace.recordonlyavro" <br>
           schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc" <br>
           schema_delete_all: true <br>
         - record_name: "com.mycorp.mynamespace.recordonlyproto" <br>
           schema_file_src_path: "/home/ubuntu/Schema/testvalue.proto" <br>
           schema_delete_curr: true <br>
         - record_name: "com.mycorp.mynamespace.recordonlyjson" <br>
           schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
       topics: <br>
         - name: test <br>
           key: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc" <br>
           value: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc" <br>
             schema_delete_all: true # Optional Delete Switch you can add to delete  schema all versions for the subject/scope <br>
             record_schemas: <br>
                  - record_name: "com.mycorp.mynamespace.address" <br>
                    schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc" <br>
         - name: test2 <br>
           key: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.proto" <br>
             record_schemas: <br>
                  - record_name: "com.mycorp.mynamespace.address" <br>
                    schema_file_src_path: "/home/ubuntu/Schema/testvalue.proto" <br>
           value: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.proto" <br>
             schema_delete_curr: true # Optional Delete Switch you can add to delete  schema all versions for the subject/scope <br>
         - name: test3 <br>
           key: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
             compatibility: "FORWARD" #--> Compatibility is an optional parameter; The schema management process sets a default 'BACKWARD' if not specified <br>
             record_schemas: <br>
                  - record_name: "com.mycorp.mynamespace.address" <br>
                    compatibilty: "FORWARD" <br>
                    schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
                    schema_delete_all: true <br>
                  - record_name: "com.mycorp.mynamespace.occupation" <br>
                    schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
           value: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
             record_schemas: <br>
                  - record_name: "com.mycorp.mynamespace.address" <br>
                    schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
                  - record_name: "com.mycorp.mynamespace.occupation" <br>
                    schema_file_src_path: "/home/ubuntu/Schema/testvalue.json" <br>
         - name: test4 <br>
           key: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc" <br>
           value: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc" <br>
         - name: test5 <br>
           key: <br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc"<br>
        - name: test6<br>
           value:<br>
             schema_file_src_path: "/home/ubuntu/Schema/testvalue.avsc"<br>
        - name: _confluent-internal # We can protect the schema of internal topics from being modified...So the mentioned topic will not have any effect when running the process<br>
         value:<br>
             schema_file_src_path: "/home/ubuntu/Schema/internalvalue.avsc"  

###### Backup and Restore Schemas

Back up Schemas in an existing cluster setting the dump_only variable to true

/*ansible-playbook --private-key ${PRIV_KEY_FILE} -i mrchostsrbacmetric.yml --extra-vars "@./schemadef.yml" --extra-vars "dump_only=true" schemas_management.yml -vvvv*/

Restore  Schemas in an new cluster setting the restore_only=truevariable to true

ansible-playbook --private-key ${PRIV_KEY_FILE} -i mrchostsrbacdata.yml --extra-vars "@./schema_dump_out.yml"  --extra-vars "restore_only=true" schemas_management.yml -vvvv



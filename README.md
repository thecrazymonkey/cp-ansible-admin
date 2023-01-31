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
    cluster_id: 

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
    rbac_cluster_whitelist: ""

# quotas management connectivity defined above
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
#!/bin/bash
#
# Dynamic Filebeat SSL Certificate Generation (Container-Ready)
#

if [ "$ENABLE_FILEBEAT" = true ]; then
    echo ""
    echo "================================"
    echo "Filebeat Configuration"
    echo "================================"
    echo ""
    # Check if required configuration exists
    if [ -z "$ELASTIC_LOGSTASH_HOSTS" ] || [ "$ELASTIC_LOGSTASH_HOSTS" = "" ]; then
        echo "ERROR: Filebeat is enabled but ELASTIC_LOGSTASH_HOSTS is not set or empty."
        echo "Please provide ELASTIC_LOGSTASH_HOSTS environment variable with Logstash host(s)."
        echo "Example: ELASTIC_LOGSTASH_HOSTS=[\"logstash-1.domain.com:5044\",\"logstash-2.domain.com:5044\"]"
        echo "Disabling Filebeat due to missing configuration."
        
        # Disable the Filebeat Supervisord App
        if [ -f /etc/supervisor/conf.d/filebeat.conf ]; then
            mv /etc/supervisor/conf.d/filebeat.conf /etc/supervisor/conf.d/filebeat.conf.disabled
        fi
        exit 1
    fi

    # Set up service configuration variables
    if [ -n "$FILEBEAT_SERVICE_ID_NAME" ]; then
        export CONFIG_FILEBEAT_SERVICE_NAME=$FILEBEAT_SERVICE_ID_NAME
    else
        export CONFIG_FILEBEAT_SERVICE_NAME=$HOSTNAME
    fi

    if [ -n "$FILEBEAT_ENVIRONMENT" ]; then
        export CONFIG_FILEBEAT_ENVIRONMENT=$FILEBEAT_ENVIRONMENT
    else
        export CONFIG_FILEBEAT_ENVIRONMENT=dev
    fi

    if [ -n "$FILEBEAT_DOMAIN_HOST" ]; then
        export CONFIG_FILEBEAT_DOMAIN=$FILEBEAT_DOMAIN_HOST
    else
        export CONFIG_FILEBEAT_DOMAIN=$HOSTNAME
    fi

    echo "Using the Service ID : ${CONFIG_FILEBEAT_SERVICE_NAME} for Filebeat"
    echo "Using the Environment : ${CONFIG_FILEBEAT_ENVIRONMENT} for Filebeat"
    echo "Using the Domain Host : ${CONFIG_FILEBEAT_DOMAIN} for Filebeat"

    # If we have Generate cert set and the CA Cert and Key is passed generate key
    if [ "$FILEBEAT_GENERATE_CERT" = true ]; then
        echo "Generating SSL certificates dynamically from ELASTIC_LOGSTASH_HOSTS..."
        
        # Check if CA cert and key are provided
        if [ -z "$LOGSTASH_SSL_CA_CERT" ] || [ -z "$LOGSTASH_SSL_CA_KEY" ]; then
            echo "ERROR: Certificate generation enabled but LOGSTASH_SSL_CA_CERT or LOGSTASH_SSL_CA_KEY is missing."
            echo "Please provide both CA certificate and key for certificate generation."
            exit 1
        fi

        # Writing CA SSL Certificates to Files
        echo "$LOGSTASH_SSL_CA_CERT" > /usr/share/ca-certificates/ca_filebeat.cert
        echo "$LOGSTASH_SSL_CA_KEY" > /etc/ssl/private/ca_logstash.key

        # Parse ELASTIC_LOGSTASH_HOSTS to extract hostnames
        PRIMARY_HOST=""
        
        echo "Parsing Logstash hosts from: $ELASTIC_LOGSTASH_HOSTS"
        
        # Remove brackets and quotes, split by comma
        HOSTS_CLEAN=$(echo "$ELASTIC_LOGSTASH_HOSTS" | sed 's/\[//g' | sed 's/\]//g' | sed 's/"//g')
        
        # Validate we have at least one host after cleaning
        if [ -z "$HOSTS_CLEAN" ]; then
            echo "ERROR: No valid hosts found in ELASTIC_LOGSTASH_HOSTS after parsing."
            exit 1
        fi

        # Counter for SAN entries
        DNS_COUNTER=1
        IP_COUNTER=1
        
        # Create SAN configuration file header
        cat > /tmp/san_config.cnf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement, nonRepudiation
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
EOF

        # Process each host from ELASTIC_LOGSTASH_HOSTS
        IFS=',' read -ra HOSTS_ARRAY <<< "$HOSTS_CLEAN"
        for host_port in "${HOSTS_ARRAY[@]}"; do
            # Trim whitespace
            host_port=$(echo "$host_port" | xargs)
            
            # Skip empty entries
            if [ -z "$host_port" ]; then
                continue
            fi
            
            # Extract hostname (remove port if present)
            hostname=$(echo "$host_port" | cut -d':' -f1)
            
            echo "Processing Logstash host: $hostname"
            
            # Set primary host (first one) for CN
            if [ -z "$PRIMARY_HOST" ]; then
                PRIMARY_HOST="$hostname"
            fi
            
            # Check if hostname is an IP address
            if [[ $hostname =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "IP.${IP_COUNTER} = $hostname" >> /tmp/san_config.cnf
                echo "Added IP SAN: $hostname"
                IP_COUNTER=$((IP_COUNTER + 1))
            else
                echo "DNS.${DNS_COUNTER} = $hostname" >> /tmp/san_config.cnf
                echo "Added DNS SAN: $hostname"
                DNS_COUNTER=$((DNS_COUNTER + 1))
            fi
        done
        
        # Validate we found at least one valid host
        if [ -z "$PRIMARY_HOST" ]; then
            echo "ERROR: No valid hostnames found in ELASTIC_LOGSTASH_HOSTS."
            exit 1
        fi

        echo "Primary host for CN: $PRIMARY_HOST"
        echo "Generated SAN configuration:"
        cat /tmp/san_config.cnf

        # Generate private key
        echo "Generating private key..."
        openssl genrsa -out /etc/ssl/private/ssl_filebeat.key 2048

        # Generate CSR with dynamic CN and SAN
        echo "Generating CSR for CN: $PRIMARY_HOST"
        openssl req -sha512 -new \
            -key /etc/ssl/private/ssl_filebeat.key \
            -out /etc/ssl/ssl_filebeat.csr \
            -config /tmp/san_config.cnf \
            -subj "/C=CA/ST=QC/O=Company Inc/CN=${PRIMARY_HOST}"

        echo "C2E9862A0DA8E970" > /tmp/serial

        # Generate certificate with SAN
        echo "Generating certificate with SAN extensions..."
        openssl x509 -days 3650 -req -sha512 \
            -in /etc/ssl/ssl_filebeat.csr \
            -CAserial /tmp/serial \
            -CA /usr/share/ca-certificates/ca_filebeat.cert \
            -CAkey /etc/ssl/private/ca_logstash.key \
            -out /etc/ssl/certs/ssl_filebeat.cert \
            -extensions v3_req -extfile /tmp/san_config.cnf

        # Verify the generated certificate
        echo "Certificate verification:"
        echo "Certificate CN:"
        openssl x509 -in /etc/ssl/certs/ssl_filebeat.cert -noout -subject
        
        echo "Certificate SAN:"
        openssl x509 -in /etc/ssl/certs/ssl_filebeat.cert -text -noout | grep -A 10 "Subject Alternative Name" || echo "Warning: No SAN found in certificate"

        # Cleanup sensitive files and variables
        unset LOGSTASH_SSL_CA_CERT
        unset LOGSTASH_SSL_CA_KEY
        rm /etc/ssl/private/ca_logstash.key
        rm /tmp/san_config.cnf
        rm /tmp/serial
        rm /etc/ssl/ssl_filebeat.csr
        
    else
        echo "Using provided SSL certificates..."
        
        # Check if certificates are provided when not generating
        if [ -z "$FILEBEAT_SSL_CERT" ] || [ -z "$FILEBEAT_SSL_CERT_KEY" ]; then
            echo "ERROR: Certificate generation disabled but FILEBEAT_SSL_CERT or FILEBEAT_SSL_CERT_KEY is missing."
            echo "Please provide both SSL certificate and key, or enable certificate generation."
            exit 1
        fi

        # Writing SSL Certificates to Files
        echo "$FILEBEAT_SSL_CERT" > /etc/ssl/certs/ssl_filebeat.cert
        echo "$FILEBEAT_SSL_CERT_KEY" > /etc/ssl/private/ssl_filebeat.key
    fi

    # Unset sensitive variables
    unset LOGSTASH_SSL_CA_CERT
    unset FILEBEAT_SSL_CERT
    unset FILEBEAT_SSL_CERT_KEY

    # Verify SSL Files Were Created Successfully
    if [ -s /usr/share/ca-certificates/ca_filebeat.cert ]; then
        echo "✓ CA certificate file created successfully"
    else
        echo "ERROR: CA certificate file creation failed or the file is empty."
        ls -lah /usr/share/ca-certificates/ | grep filebeat || echo "No filebeat cert found"
        exit 1
    fi
    
    if [ -s /etc/ssl/certs/ssl_filebeat.cert ]; then
        echo "✓ SSL certificate file created successfully"
    else
        echo "ERROR: SSL certificate file creation failed or the file is empty."
        ls -lah /etc/ssl/certs/ | grep filebeat || echo "No filebeat cert found"
        exit 1
    fi
    
    if [ -s /etc/ssl/private/ssl_filebeat.key ]; then
        echo "✓ SSL private key file created successfully"
    else
        echo "ERROR: SSL private key file creation failed or the file is empty."
        ls -lah /etc/ssl/private/ | grep filebeat || echo "No filebeat key found"
        exit 1
    fi

    echo "✅ Filebeat SSL configuration completed successfully"
    echo "Certificate will work with hosts: $(echo $ELASTIC_LOGSTASH_HOSTS | sed 's/\[//g' | sed 's/\]//g' | sed 's/"//g')"

    echo "Fielbeat configuration completed successfully"
    echo ""
    echo "================================"
    echo ""
else
    echo "Filebeat disabled via ENABLE_FILEBEAT=false"
    # Disable the Filebeat Supervisord App
    if [ -f /etc/supervisor/conf.d/filebeat.conf ]; then
        mv /etc/supervisor/conf.d/filebeat.conf /etc/supervisor/conf.d/filebeat.conf.disabled
        echo "Filebeat service configuration disabled"
    fi
fi
#!/bin/bash
#
#
#

if [ "$ENABLE_FILEBEAT" = true ]; then
    if [ -n "$FILEBEAT_SERVICE_ID_NAME" ]; then
        export CONFIG_FILEBEAT_SERVICE_NAME=$FILEBEAT_SERVICE_ID_NAME
    else
        export CONFIG_FILEBEAT_SERVICE_NAME=$HOSTNAME
    fi

    echo "Using the Service ID : ${CONFIG_FILEBEAT_SERVICE_NAME} for Filebeat"

    

    # If we have Generate cert set and the CA Cert and Key is passed generate key
    if [ "$FILEBEAT_GENERATE_CERT" = true ]; then
        # Writing CA SSL Certificates to Files
        if [ -n "$LOGSTASH_SSL_CA_CERT" ]; then
            echo "$LOGSTASH_SSL_CA_CERT" > /usr/share/ca-certificates/ca_filebeat.cert
        fi
        if [ -n "$LOGSTASH_SSL_CA_KEY" ]; then
            echo "$LOGSTASH_SSL_CA_KEY" >  /etc/ssl/private/ca_logstash.key
        fi

        echo "[ usr_cert ]
basicConstraints = CA:FALSE
nsCertType = client, server
nsComment = \"OpenSSL FileBeat Server / Client Certificate\"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement, nonRepudiation
extendedKeyUsage = serverAuth, clientAuth

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth" > /tmp/ssl_extfile.cnf

        # Generate private key
        openssl genrsa -out /etc/ssl/private/ssl_filebeat.key 2048

        # Generate CSR with provided arguments
        openssl req -sha512 -new -key /etc/ssl/private/ssl_filebeat.key -out /etc/ssl/ssl_filebeat.csr -subj "/C=CA/ST=QC/O=Company Inc/CN=example.com"

        echo "C2E9862A0DA8E970" > /tmp/serial

        # Generate client certificate
        openssl x509 -days 3650 -req -sha512 \
        -in /etc/ssl/ssl_filebeat.csr \
        -CAserial /tmp/serial \
        -CA /usr/share/ca-certificates/ca_filebeat.cert \
        -CAkey /etc/ssl/private/ca_logstash.key \
        -out /etc/ssl/certs/ssl_filebeat.cert \
        -extfile /tmp/ssl_extfile.cnf

        # Unset the CA As soon as it been used
        unset LOGSTASH_SSL_CA_CERT
        unset LOGSTASH_SSL_CA_KEY
        # Delete the key as it no longer needed
        rm /etc/ssl/private/ca_logstash.key
        rm /tmp/ssl_extfile.cnf
        rm /tmp/serial
    else

        # Writing SSL Certificates to Files
        if [ -n "$FILEBEAT_SSL_CERT" ]; then
            echo "$FILEBEAT_SSL_CERT" > /etc/ssl/certs/ssl_filebeat.cert
        fi
        if [ -n "$FILEBEAT_SSL_CERT_KEY" ]; then
            echo "$FILEBEAT_SSL_CERT_KEY" > /etc/ssl/private/ssl_filebeat.key
        fi

    fi

    # Unsetting Sensitive Variables
    unset LOGSTASH_SSL_CA_CERT
    unset FILEBEAT_SSL_CERT
    unset FILEBEAT_SSL_CERT_KEY

    # Verifying SSL Files Were Created Successfully
    if [ -s /usr/share/ca-certificates/ca_filebeat.cert ]; then
        echo "File '/usr/share/ca-certificates/ca_filebeat.cert' was created successfully with content."
    else
        echo "Error: File '/usr/share/ca-certificates/ca_filebeat.cert' creation failed or the file is empty."
        ls -lah /usr/share/ca-certificates/
        exit 1
    fi
    if [ -s /etc/ssl/certs/ssl_filebeat.cert ]; then
        echo "File '/etc/ssl/certs/ssl_filebeat.cert' was created successfully with content."
    else
        echo "Error: File '/etc/ssl/certs/ssl_filebeat.cert' creation failed or the file is empty."
        ls -lah /etc/ssl/certs/
        exit 1
    fi
    if [ -s /etc/ssl/private/ssl_filebeat.key ]; then
        echo "File '/etc/ssl/private/ssl_filebeat.key' was created successfully with content."
    else
        echo "Error: File '/etc/ssl/private/ssl_filebeat.key' creation failed or the file is empty."
        ls -lah /etc/ssl/private/
        exit 1
    fi
else
    echo "Filebeat Disabled."
    # Disable the Filebeat Supervisord App
    if [ -f /etc/supervisor/conf.d/filebeat.conf ]; then
        mv /etc/supervisor/conf.d/filebeat.conf /etc/supervisor/conf.d/filebeat.conf.disabled
    fi
fi
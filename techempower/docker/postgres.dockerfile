#FROM registry.redhat.io/rhel8/postgresql-13:latest
FROM quay.io/centos7/postgresql-13-centos7:latest

ADD create-postgres-data.sql /tmp/create-postgres-data.sql
TFB postgres database
=====================

Build image:

```shell
$ docker build -f ./postgres.dockerfile --tag johara/tfb-postgres  .
Sending build context to Docker daemon  7.168kB
Step 1/2 : FROM quay.io/centos7/postgresql-13-centos7:latest
 ---> 32cc569aeaf5
Step 2/2 : ADD create-postgres-data.sql /tmp/create-postgres-data.sql
 ---> 0c1cc9fcf423
Successfully built 0c1cc9fcf423
Successfully tagged johara/tfb-postgres:latest
```

Tag Image:

```shell
$ docker tag 0c1cc9fcf423 quay.io/johara/tfb-database:latest
```

Login:

```shell
$ docker login quay.io
```

Push Image:

```shell
$ docker push quay.io/johara/tfb-database
Using default tag: latest
The push refers to repository [quay.io/johara/tfb-database]
987b88cd2691: Pushed 
...
53498d66ad83: Layer already exists 
latest: digest: sha256:1f6e8facebf6b4f3de40e1dfd1b7e5649d80845c7810146f8b36c23097367c7c size: 2411
```

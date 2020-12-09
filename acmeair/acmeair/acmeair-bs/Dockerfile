FROM websphere-liberty:kernel

ADD Dockerfile /root/Dockerfile

RUN rm -rf /opt/ibm/wlp/usr/servers/defaultServer/server.xml
ADD server.xml /opt/ibm/wlp/usr/servers/defaultServer/server.xml

RUN installUtility install --acceptLicense defaultServer
RUN rm -rf /opt/ibm/wlp/usr/servers/defaultServer/workarea

ADD ./build/libs/*.war /opt/ibm/wlp/usr/servers/defaultServer/apps

EXPOSE 80

ENV AUTH_SERVICE=nginx1/auth/acmeair-as
ENV MONGO_HOST=booking_db1
ENV MONGO_DBNAME=acmeair_bookingdb

CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]

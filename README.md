# Kruize Benchmarks

The goal of this repo is to run various benchmarks on Kruize projects to help tune them while running in kubernetes.

- We do not have sources for the external benchmarks except Acmeair
- We are merely making it container and kubernetes friendly
- We are adding scripts to evaluate all benchmarks similarly
- We do NOT own the external benchmarks and provide pointers to the github repos where the original sources can be found.

##  Benchmarks
- [acmeair](/acmeair)
  - A Fictitious Airline Booking Application
  - Transactional, Uses WebSphere Liberty, Eclipse OpenJ9 JVM
  - Has a copy of source code forked from the [main repo](https://github.com/blueperf/acmeair-monolithic-java) which has date type changes and is microservice based.
- [galaxies](/galaxies)
  - Quarkus Sample Application
  - REST CRUD, uses Quarkus, Hotspot JVM
  - In house application
- [petclinic](/spring-petclinic)
  - Spring PetClinic Sample Application
  - REST CRUD, uses SpringBoot, Hotspot JVM
- [TechEmpower](/techempower) 
  - Web application frameworks on many languages
  - Uses Java+Quarkus based framework

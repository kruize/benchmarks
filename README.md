# Kruize Benchmarks

The goal of this repo is to run various benchmarks on Kruize projects to help tune them while running in kubernetes.

- We do not have sources for the external benchmarks
- We are merely making it container and kubernetes friendly
- We are adding scripts to evaluate all benchmarks similarly
- We do NOT own the external benchmarks and provide pointers to the github repos where the original sources can be found.

##  List of Benchmarks
- [acmeair](/acmeair)
  - A Fictitious Airline Booking Application (Monolithic version)
  - Transactional, Uses WebSphere Liberty, Eclipse OpenJ9 JVM
- [galaxies](/galaxies)
  - Quarkus Sample Application
  - REST CRUD, uses Quarkus, Hotspot JVM
- [petclinic](/spring-petclinic)
  - Spring PetClinic Sample Application
  - REST CRUD, uses SpringBoot, Hotspot JVM
- [TechEmpower](/techempower) 
  - Web application frameworks on many languages.
  - Uses Java+Quarkus based framework


# Instructions to run the petclinic application using scripts 

# Create the required setup
Generate the images required for the setup 
`./scripts/petclinic-setup.sh setup_info`

setup_info: (do_setup/use_image)

do_setup : Build the setup using jar files

Pre-requisites: javac and git 

```
$./scripts/petclinic-setup.sh do_setup
Checking prereqs...done
Building petclinic application...done
Building jmeter with petclinic driver...done
Running petclinic with inbuilt db...done
```
use_image : Use the image to create the setup
`use_image petclinic_imagename jmeter_imagename`


```
$./scripts/petclinic-setup.sh use_image kruize/spring-petclinic:2.2.0 kruize/jmeter_petclinic:3.1
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic with inbuilt db...done

```

both `petclinic_imagename` and `jmeter_imagename` are optional, If the image names are not specified then the default image `kruize/spring-petclinic:2.2.0` will be considered for petclinic and `kruize/jmeter_petclinic:3.1` will be considered for jmeter.

```
$ ./scripts/petclinic-setup.sh use_image 
Checking prereqs...done
Pulling the jmeter image...done
Running petclinic with inbuilt db...done
```

# Run the load
Apply the load to the benchmark
`./scripts/petclinic-load.sh load_info`

load_info: [load type] [Number of iterations of the jmeter load] [ip_addr / namespace]"

load type: docker icp openshift

Number of iterations of the jmeter load: Number of times you want to run the load. It is optional, if is not specified then by default it will be considered as 5 iterations.

ip_addr: IP address of the machine. It is optional, if is not specified then the get_ip function written inside the script will get the IP address of the machine.

`jmeter-petclinic:3.1` is the image used to apply the load


```
$./scripts/petclinic-load.sh docker 2 
#########################################################################################
                             Starting Iteration 1                                  
#########################################################################################
Running jmeter load with the following parameters
JHOST=192.168.1.8 JDURATION=20 JUSERS=150 JPORT=32334 
jmter logs Dir : /home/shruthi/kruize/tests/Spring-petclinic/logs/petclinic-202009111154
#########################################################################################
                             Starting Iteration 2                                  
#########################################################################################
Running jmeter load with the following parameters
JHOST=192.168.1.8 JDURATION=20 JUSERS=300 JPORT=32334 
jmter logs Dir : /home/shruthi/kruize/tests/Spring-petclinic/logs/petclinic-202009111154
#########################################################################################
				Displaying the results				       
#########################################################################################
RUN , THROUGHPUT , PAGES , AVG_RESPONSE_TIME , ERRORS
1,310.7,6281,60,0
2,687.1,14059,25,0
```
Above image shows the logs of the load run, and it processes and displays the output at the end

# Cleanup
`$ ./scripts/petclinic-cleanup.sh`


# Note for RHEL 8.0 users
podman docker should have the latest network version to work.

# Openshift
To deploy the benchmark use `petclinic-deploy-openshift.sh`

`./scripts/petclinic-deploy-openshift.sh deploy_info`

deploy_info: Benchmark server , Namespace , Manifests directory and Results directory path

Benchmark server: Name of the cluster you are using

Namespace: openshift-monitoring

Manifests directory: Path where the manifest directory exists

Results directory path: Location where you want to store the results




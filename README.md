# How stay DRY using Dockerfile and Jenkinsfile with Microservices

* [The Context](#the-context)
* [The Problem](#the-problem)
* [The Solution](#the-solution)
* [Alternatives](#an-alternative)

### TL;DR
When using Jenkinsfile and Dockerfile with Microservices you are typically repeating the same boilerplate code over and over again. This becomes a problem when the number of Microservices - and Git branches - start to increase.

In order to stay [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) you can leverage the `ONBUILD` Dockerfile keyword and a global var to define a re-usable pipeline.

See the [Dockerfile](Dockerfile) and [Jenkinsfile](Jenkinsfile) in this project for an example on how that can be done!

## The Context
Let's say you are using Microservices. Following best practices, each Microservice has its own source code repository. You start out with a few but this rapidly grows to a few dozen and with time you are managing a few hundred, perhaps more.

Each Microservice is built as a Docker image which is deployed to a cluster using a Container Manager, perhaps Kubernetes. Having fully bought into the whole DevOps and automation concept you have CI/CD pipelines to build and deploy your Microservices.

Jenkins you use out of habit, because this is what you know or because it seems to be a very popular choice. Who really knows why, but Jenkins is what you are currently stuck with.

Git is used for version control and the mere presence of a Jenkinsfile on a branch push to your Git repository manager triggers a build using the Jenkins multibranch plugin, this works great!

Once the initial Jenkinsfile is in place everything is automated.

Typically your Microservices look pretty much alike from a CI/CD perspective but the simplest solution was to put the Dockerfile in each repository, just beside the Jenkinsfile.

The Dockerfile is where you put all the Microservice specic stuff required for CI/CD and running your application such as container labels, environment variables etc.

Thus the Git repository root contains two boilerplate files, one for Docker and one for Jenkins:

```
Dockerfile
Jenkinsfile
```

In most cases these files are almost identical apart from label and environment values. In order to facilitate for developers these they are automaticallly generated using a template mechanism of some sorts. Perhaps the nifty [Docker Enterprise Desktop](https://blog.docker.com/2018/12/introducing-desktop-enterprise/) shipping as a part of Docker EE 3.0

## The Problem
Requirements change or perhaps there is a bug but for whatever reason either the standard Jenkins pipeline and or Dockerfile change over time.

With a large number of Microservices that each has its own version of the `Jenkinsfile` and `Dockerfile`, multiple branches for handling the master line, development, features and bugs the relevance of the [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) principle starts to sink in and you realize you have a [WET](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) solution...

**For every change that comes along you now have to check out the code make the same edit and push for every single branch.**

Cheery-picking helps but still there is a lot of typing, committing and pushing going on that increases the risk of typos and inconsistencies, in particular if done by multiple teams and developers.

Of course, nothing prevents you from automating changes like this, but it would throwing code at a sympton instead of resolving the root cause.

## The solution
A solution that addresses the WET root cause comes in two parts:

* Use one (or more) custom base image in your Dockerfiles
* Use a Jenkins pipeline DSL in your Jenkinsfiles

### Using a Custom Base Image
A custom base image should contain all things common to your downstream Microservices, things like

* standard image labels
* log configuration files
* common bootstrap shell scripts
* runtime users
* ...

The custom base image in itself uses a more standard upstream, such as the alpine version for your language.

Some things depend on the downstream Microservice, however. What if you have a label containing the name or version of the Microservice? These are only known at build time of the Microservice itself, not when we are building the base image.

The key here is Docker's `ONBUILD` keyword which allows you to customize your base image to your Microservice using build time arguments.

For example we can set a `version` container label on the downstram Microservice with

```
ONBUILD ARG VERSION
ONBUILD LABEL version=${VERSION}
```

Given that the base image is called `mybase` we then use a `Dockerfile` in Microservice repository with the following content:

```
FROM mybase:latest
```

**That's it. That is the entire Dockefile.**

To build it we have to supply a build argument to the docker command, something along the lines of

```
docker build --arg VERSION=1.3.9 .
```

The resulting image will then contain the container label `version: 1.3.9` (surprise!).

**If the we want to change something, perahps adding another standard label, update the logic to the bootstrap script, change the log configuration or perhaps just update the to the latest alpine for Java, we only change it in one place, i.e. in the custom base image `mybase`.**

Of course, we still need to trigger the rebuild and redeployment of all our Microservices but the DRY principle is respected.

The beauty of this approach is that we still have our `Dockerfile` in each Git repository which can be customized if there is a real need. Just because there is a default base image does not mean that we force everybody to use it all the time. All our CI/CD tools will still work exactly the same and the only drawback is that we now have one exception to manage separately from the rest.

Please see [Dockerfile](Dockerfile) for a more complete example of how a custome base image can look like.

### Use a Jenkins pipeline DSL
Jenkins has support for building custom [pipeline DSL](https://jenkins.io/doc/book/pipeline/syntax/) in Groovy.

This can be quite complicated given that Jenkins Groovy flavour is not 100% vanilla and it has a sour twist - not all Groovy features are available and you need follow certain conventions. If you existing DSL that comes out of the box and avoid custom Groovy code you should be good though.

Here we will not go into details on how to develop a Pipeline DSL but the basic idea is that you define a global variable for the entire pipeline and use it your Jenkinsfiles.

Given a DSL library called `mylib` and a global var called `mavenPipeline` the Microservice `Jenkinsfile` could look like this:

```
@Library("mylib@latest") _
mavenPipeline(java: '8')
```
(Note the trailing underscore which is a package placeholder to which the annotation is attached)

Here we assume that `mavenPipeline` has parameter support for the java version to use. You can have others as well, if you like, but be careful not to repeat yourself with too many boilerplate settings.

Now, if there is a change to how the Microservice is built, how continous delivery is done or perhaps if a new quality gate is added as a separate step, there is no need to change any of the Microservices. You just change the definition of the `mavenPipeline`.

Similar to how we handle the `Dockerfile` we can manage a custom `Jenkinsfile` where needed.

## The Example
This Git repository contains a more complete example of a custom base image. It assumes Java based Microservices built by Maven but the concept should be easily adaptable to any language or platform.

* [pom.xml](pom.xml) for building the image
* [bootstrap.sh](bootstrap.sh) docker entrypoint for launching the microservice
* [jmxremote.access](src/files/jmxremote.access) for configuring remote Java JMX access
* [logback.xml](src/files/logback.xml) for log configuration

To build the base image you can launch

```
mvn clean package
```
If you want to deploy the base image you need to configure Maven SCM settings and make sure to change the `docker.namespace` to you Docker Hub account. If you are using a private registry you also need to update the `docker.registry` property and probably add credentials in Maven's `settings.xml` - YMMV!

You can then run...
```
mvn clean package
```
... and Maven will happily deploy the (empty) JAR to your Maven registry and Docker image to Docker Hub or whatever you have configured.

You Microservices should use Dockerfile along the lines of [Dockerfile.microservice](Dockerfile.microservice) in the root of each Microservice repository branch.

**(!) Note that the example requires Java 8 and Maven 3.5 to run!**

### Jenkinsfile
The [Jenkinsfile](Jenkinsfile) will not work without you writing a custom DSL and adding the `mavenPipeline` global variable to your Jenkins instance.

### POM
The Maven POM builds the Docker image using Spotify's  [dockerfile-maven-plugin](https://github.com/spotify/dockerfile-maven).

The POM is configured to

* Download all dependencies which are then added to the image
* Create an executable JAR file which is also added to the image
* Build the image if a Dockerfile is present using a Maven `docker` profile

The base image pom.xml has two dependencies: the [logback-classic](https://logback.qos.ch/) and [logstash-logback-encoder](https://github.com/logstash/logstash-logback-encoder) libraries. These are shared by all our Microservices and are required for the  [logback.xml](src/files/logback.xml) configuration file.

The configuration found in the POM can be used both for building the base image and for building the Microservices, indeed given the use of a Maven `docker` profile it can be used for any Maven project with or without Dockerfiles.

In order to stay DRY the plugin configuration in the POM should be put in a parent pom shared by all Microservice projects. Or you will again end up with a WET solution...


### Entrypoint
The `bootstrap.sh` shell script that serves as the docker image entry point.

It sets a few variables used for configuring the Microsevice and launches the microservice iteslf with a number of standard JVM arguments, including configuration of logback and JMX.

A nifty feature is that it will pass along all docker command line arguments to the Java runtime.

## Alternatives
There are of course other solutions that still respect the DRY principle.

For example it might be possible to get rid of the Dockerfile. If you are building with Maven a good candidate is to use [JIB](https://github.com/GoogleContainerTools/jib/tree/master/jib-maven-plugin).

Instead of using Jenkinsfiles you may use custom Git repostory manager hooks to provision new pipelines for repositories and branches as needed. This seems like a rather cumbersome approach though.

Looking into other CI/CD tools than Jenkins can also be a good idea given the challengeds in writing pipeline DSL in Groovy. Any feedback on good alternatives that stay DRY is welcome!

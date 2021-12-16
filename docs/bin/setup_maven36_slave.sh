#!/bin/sh
PROJECT=ci-cd
JENKINS_SLAVE=maven36-with-tools
MAVEN_VERSION=3.6.3
JMETER_VERSION=5.4.1
echo "################  ${JENKINS_SLAVE} ##################"
oc new-build --strategy=docker -D $'FROM quay.io/openshift/origin-jenkins-agent-maven:4.1\n
   USER root\n
   RUN curl https://copr.fedorainfracloud.org/coprs/alsadi/dumb-init/repo/epel-7/alsadi-dumb-init-epel-7.repo -o /etc/yum.repos.d/alsadi-dumb-init-epel-7.repo && \ \n
   curl https://raw.githubusercontent.com/cloudrouter/centos-repo/master/CentOS-Base.repo -o /etc/yum.repos.d/CentOS-Base.repo && \ \n
   curl http://mirror.centos.org/centos-7/7/os/x86_64/RPM-GPG-KEY-CentOS-7 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \ \n
   curl -L -o /tmp/apache-maven-3.6.3-bin.tar.gz https://www-eu.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz && \ \n
   gzip -d /tmp/apache-maven-3.6.3-bin.tar.gz && \ \n
   tar -C /opt -xf /tmp/apache-maven-3.6.3-bin.tar && \ \n
   rm -f /tmp/apache-maven-3.6.3-bin.tar && \ \n
   chmod -R 755 /opt/apache-maven-3.6.3 && \ \n
   chown -R 1001:0 /opt/apache-maven-3.6.3 && \ \n
   curl -L -o /tmp/nexus-cli https://s3.eu-west-2.amazonaws.com/nexus-cli/1.0.0-beta/linux/nexus-cli  && \ \n
   mkdir -p /opt/nexus-cli && \ \n
   mv /tmp/nexus-cli /opt/nexus-cli && \ \n
   chmod -R 755 /opt/nexus-cli/nexus-cli && \ \n
   chown -R 1001:0 /opt/nexus-cli && \ \n
   curl -L -o /tmp/jmeter.tgz https://downloads.apache.org//jmeter/binaries/apache-jmeter-5.4.1.tgz && \ \n
   tar -C /opt -xf /tmp/jmeter.tgz && \ \n
   rm -f /tmp/jmeter.tgz && \ \n
   chmod -R 755 /opt/apache-jmeter-5.4.1 && \ \n
   chown -R 1001:0 /opt/apache-jmeter-5.4.1 && \ \n
   DISABLES="--disablerepo=rhel-server-extras --disablerepo=rhel-server --disablerepo=rhel-fast-datapath --disablerepo=rhel-server-optional --disablerepo=rhel-server-ose --disablerepo=rhel-server-rhscl" && \ \n
   yum $DISABLES -y --setopt=tsflags=nodocs install skopeo && yum clean all   \n
   ENV PATH=/opt/apache-maven-3.6.3/bin:/opt/nexus-cli:/opt/apache-jmeter-5.4.1/bin:$PATH \n
   USER 1001' --name=${JENKINS_SLAVE} -n ${PROJECT}
# uid=1000680000(default) gid=0(root) groups=0(root),1000680000
# 
#    yum $DISABLES -y --setopt=tsflags=nodocs install podman && \ \n
#    yum $DISABLES -y --setopt=tsflags=nodocs install java-11-openjdk-devel && \ \n
# Quay => FROM openshift/jenkins-slave-base-centos7:v3.11 
# RUN yum -y --setopt=tsflags=nodocs install skopeo && yum clean all \n

# oc new-build --strategy=docker -D $'FROM quay.io/openshift/origin-jenkins-agent-base:4.9  \n
#    ENV MAVEN_VERSION=3.6.3 \ \n
#    PATH=$PATH:/opt/maven/bin \n
#    RUN curl -L --output /tmp/jdk.tar.gz https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz && \ \n
#    tar zxf /tmp/jdk.tar.gz -C /usr/lib/jvm && \ \n
#    rm /tmp/jdk.tar.gz && \ \n
#    update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-11.0.2/bin/java 20000 --family java-1.11-openjdk.x86_64 && \ \n
#    update-alternatives --set java /usr/lib/jvm/jdk-11.0.2/bin/java \n
#    RUN curl -L --output /tmp/apache-maven-bin.zip  https://www-eu.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip && \ \n
#    unzip -q /tmp/apache-maven-bin.zip -d /opt && \ \n
#    ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven && \ \n
#    rm /tmp/apache-maven-bin.zip && \ \n
#    mkdir -p $HOME/.m2 \n
#    RUN chown -R 1001:0 $HOME && chmod -R g+rw $HOME \n
#    USER 1001' --name=${JENKINS_SLAVE} -n ${PROJECT}
echo "Wait 15 sec for build to start"
sleep 15
oc logs build/${JENKINS_SLAVE}-1 -f -n ${PROJECT}
oc get build/${JENKINS_SLAVE}-1 -n ${PROJECT}

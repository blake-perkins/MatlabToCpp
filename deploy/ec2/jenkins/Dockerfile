FROM jenkins/jenkins:lts-jdk17

# Skip the setup wizard (CasC handles configuration)
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Install plugins from plugins.txt
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy Configuration as Code file
COPY casc.yaml /var/jenkins_home/casc.yaml

# Copy seed job definition
COPY seed-job.groovy /var/jenkins_home/seed-job.groovy

# Install build tools inside Jenkins container
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    g++ \
    make \
    python3 \
    python3-pip \
    python3-venv \
    xvfb \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Conan 2
RUN pip3 install --break-system-packages conan==2.* jsonschema

USER jenkins

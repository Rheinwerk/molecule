ARG   OS_VERSION=stable

FROM  --platform=$BUILDPLATFORM debian:${OS_VERSION}

ARG   DEBIAN_FRONTEND=noninteractive

ARG   ANSIBLE_VERSION \
      ANSIBLE_LINT_VERSION \
      PACKER_VERSION \
      PACKER_ANSIBLE_VERSION \
      PACKER_AMAZON_VERSION \
      TERRAFORM_VERSION \
      TFLINT_VERSION \
      YQ_VERSION

RUN   groupadd -g 1001 vsts && useradd -u 1001 -g 1001 -s /bin/bash -d /home/vsts vsts
RUN   gpasswd -a vsts sudo
COPY  ansible_collections.yml /home/vsts/ansible_collections.yml
COPY  provider.tf /home/vsts/provider.tf

# Install dependencies.
RUN   apt-get update \
      && apt-get install -y --no-install-recommends \
         apt-transport-https \
         bash \
         gnupg \
         ca-certificates \
         curl \
         git \
         less \
         locales \
         lsb-release \
         make \
         parallel \
         procps \
         software-properties-common \
         sudo \
         tar \
         unzip \
         wget \
         xz-utils \
         zip \
      && apt-get clean \
      && rm -Rf /var/lib/apt/lists/* \
      && rm -Rf /usr/share/doc && find /usr/share/man -type f -delete \
      && rm -rf /tmp/* /var/tmp/*;

# Install Python 3.12
COPY  pascalroeleven.sources /etc/apt/sources.list.d/pascalroeleven.sources
COPY  pascalroeleven.gpg /etc/apt/keyrings/deb-pascalroeleven.gpg

RUN   apt-get update \
      && apt-get -y install python3.12 python3.12-dev python3.12-venv

# Use Python 3.12 when calling python3 + setup
RUN   update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2 \
      && rm /usr/lib/python*/EXTERNALLY-MANAGED \
      && python3 -m ensurepip --upgrade \
      && python3 -m pip install --upgrade setuptools

# Create venv and install tools
RUN   python3.12 -m venv /opt/ansible_virtualenv \
      && . /opt/ansible_virtualenv/bin/activate \
      && pip3 install --no-cache-dir --no-compile ansible-core==${ANSIBLE_VERSION} ansible-lint==${ANSIBLE_LINT_VERSION} yamllint \
      && ln -s /opt/ansible_virtualenv/bin/ansible* /usr/bin/ \
      && ln -s /opt/ansible_virtualenv/bin/yamllint /usr/bin/

# Install Packer + Plugins
RUN   curl -sLSfo packer.zip https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_$(dpkg --print-architecture).zip && unzip -o packer.zip && mv packer /usr/bin -f && rm packer.zip

# Install Terraform
RUN   curl -sLSfo terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_$(dpkg --print-architecture).zip && unzip -o terraform.zip && mv terraform /usr/bin -f && rm terraform.zip

# Install TFlint
RUN   curl -sLSfo tflint.zip https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_$(dpkg --print-architecture).zip  && unzip -o tflint.zip && mv tflint /usr/bin -f && rm tflint.zip

# Install YQ
RUN   curl -sLSfo /usr/bin/yq  https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_$(dpkg --print-architecture) && chmod +x /usr/bin/yq

# Install Node.js
RUN   curl -sL https://deb.nodesource.com/setup_20.x | bash - && \
      apt-get install -y nodejs

# sudo for all
RUN     echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# cleanup apt mess
RUN     apt-get purge -y man-db && apt-get clean \
        && rm -rf \
                /var/lib/apt/lists/* \
                /tmp/* \
                /var/tmp/* \
                /usr/share/doc/* \
                /usr/share/man/* \
                /usr/share/locale/*

# fatal: detected dubious ownership in repository at '/git'
RUN   git config --global --add safe.directory /git

RUN   chown -R 1001:1001 /home/vsts
USER  1001
WORKDIR /home/vsts

RUN   ansible-galaxy collection install -r ~/ansible_collections.yml
RUN   packer plugins install "github.com/hashicorp/amazon" ${PACKER_AMAZON_VERSION} && \
      packer plugins install "github.com/hashicorp/ansible" ${PACKER_ANSIBLE_VERSION}
RUN   terraform init

# No ENTRYPOINT
ENTRYPOINT []
CMD []

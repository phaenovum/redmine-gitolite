FROM redmine:4.1.1-passenger

LABEL MAINTAINERS="Lars Möllendorf <moellendorf@phaenovum.de>"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    # gitolite dependencies
    apt-get install -yq build-essential libssh2-1 libssh2-1-dev cmake libgpg-error-dev \
    pkg-config gitolite3 sudo

COPY sudoers.d.redmine /etc/sudoers.d/redmine
RUN chmod 644 /etc/sudoers.d/redmine && \
    adduser --system --shell /bin/bash --group --disabled-password --home /home/git git

# supervisor installation && 
# create directory for child images to store configuration in
RUN apt-get -y install supervisor && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /etc/supervisor/conf.d && \
    mkdir -p /var/run/supervisor

# supervisor base configuration
COPY supervisor.conf /etc/supervisor.conf
COPY ssh.conf /etc/supervisor/conf.d/ssh.conf
COPY passenger.conf /etc/supervisor/conf.d/passenger.conf

# sshd setup
RUN mkdir /run/sshd

# default command
CMD ["supervisord", "-c", "/etc/supervisor.conf"]


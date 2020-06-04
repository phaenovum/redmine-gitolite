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

RUN /etc/init.d/ssh start

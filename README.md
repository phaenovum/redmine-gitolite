This docker image is based on [Docker "Official Image"](https://github.com/docker-library/official-images#what-are-official-images) for [`redmine`](https://hub.docker.com/_/redmine/) and integrates all dependencies for [Redmine Git Hosting](http://redmine-git-hosting.io/) plugin.

# Docker Compose

This is the directory structure in use:

```
docker
├── mysql
└── redmine
    ├── certs    // certificates
    ├── config   // redmine config
    ├── etc_ssh  // SSH server config
    ├── files    // redmine files
    ├── gitolite // gitolite HOME
    ├── plugins  // redmine plugins
    ├── public   // redmine public www files
    └── ssh      // SSH config of redmine user
```

Create it with:

```bash
mkdir -p docker/{mysql,redmine/{certs,config,etc_ssh,files,gitolite,plugins,public,ssh}}
```
And place your existing files there.

The `docker-compose.yml`:

```yml
# Use root/example as user/password credentials
#version: '3.1'
version: '2'

services:

  redmine:
    image: redmine-gitolite:4.1.1-passenger
    restart: always
    ports:
      - 80:3000
      - 443:3443
      - 22:2222
    expose:
      - "3443"
      - "2222"
    volumes:
        - ./redmine/files:/usr/src/redmine/files
        - ./redmine/plugins:/usr/src/redmine/plugins
        - ./redmine/public/themes/phaenovum_new:/usr/src/redmine/public/themes/phaenovum_new
        - ./redmine/config/configuration.yml:/usr/src/redmine/config/configuration.yml
        - ./redmine/certs:/etc/ssl/redmine:ro
        - ./redmine/etc_ssh:/etc/ssh
        - ./redmine/ssh:/home/redmine/.ssh
        - ./redmine/gitolite:/home/git
    environment:
      REDMINE_DB_MYSQL: db
      REDMINE_DB_USERNAME: redmine
      REDMINE_DB_PASSWORD: <secret>
      REDMIN_PLUGINS_MIGRATE: 1
    command: supervisord -c /etc/supervisor.conf

  db:
    image: mariadb:10.4.13
    restart: always
    volumes:
        - ./mysql:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: <secret>
```

# MySQL Data Migration

```bash
mysqldump --user=redmine --password redmine > ~/$(date --iso-8601=minutes)_redmine.sql
docker run --name docker_db_1 -e MYSQL_ROOT_PASSWORD=<password> -v /path/to/docker/mysql:/var/lib/mysql  mariadb:10.4.13
docker container exec -it docker_db_1 mysql -uroot -p
```

```mysql
CREATE USER redmine IDENTIFIED BY 'password';
CREATE DATABASE redmine; GRANT ALL PRIVILEGES ON redmine.* TO redmine;
quit;
```

```bash
docker exec -i docker_db_1 mysql -uroot -ppassword redmine < $(ls -1c ~/*_redmine.sql | head -n1)
docker stop docker_db_1
```

# Fixing File Ownerships

If you migrate existing redmine or gitolite files into the docker volumes directories you have to fix their ownership.

View the UID and GID of `redmine` and `git` users in the running container:

```bash
cd docker
docker-compose up -d
docker container exec -it docker_redmine_1 bash
id -u redmine
id -g redmine
id -u git
id -g git
exit
docker-compose down
```

Change the ownership accordingly:

```bash
sudo chown 106:107 -R /path/to/docker/redmine/gitolite
sudo chown 999:999 -R /path/to/docker/redmine/config
sudo chown 999:999 -R /path/to/docker/redmine/files
sudo chown 999:999 -R /path/to/docker/redmine/plugins
sudo chown 999:999 -R /path/to/docker/redmine/public
sudo chown 999:999 -R /path/to/docker/redmine/ssh
```

# SSH

Gitolite uses SSH. It is necessary to run its SSH server inside the docker container and best practice to let it listen on port 22. For this to work make sure your host's SSH server uses another port.

# Plugins

```bash
docker container exec -it --user redmine docker_redmine_1 bash
cd plugins/
git clone -b v2-stable git://github.com/alphanodes/additionals.git additionals
git clone https://github.com/jbox-web/redmine_git_hosting.git
cd redmine_git_hosting/
git checkout 4.0.1
cd ../..
RAILS_ENV=production NAME=additionals rake redmine:plugins:migrate
RAILS_ENV=production NAME=redmine_git_hosting rake redmine:plugins:migrate
```

Restart redmine:

```bash
passenger-config restart-app
*** Cleaning stale instance directory /tmp/passenger.RqbTnq4
*** Cleaning stale instance directory /tmp/passenger.HWLlLsW
*** Cleaning stale instance directory /tmp/passenger.swN1bC1
Please select the application to restart.
Tip: re-run this command with --help to learn how to automate it.
If the menu doesn't display correctly, press '!'

 ‣   /usr/src/redmine (production)
     Cancel

Restarting /usr/src/redmine (production)
```

# Git Hosting Plugin

Do the [Gitolite setup](https://gitolite.com/gitolite/install#setup) in the
container. To enter the container as `git` user:

```bash
docker container exec -it --user git docker_redmine_1 bash
```

In Redmine configure Gitolite Plugin according to [Finish installation - Configuration](http://redmine-git-hosting.io/get_started/).

The most important settings:

## Gitolite SSH Configuration

Within the Container SSH Server listens on port 2222:

- Gitolite username: git
- Gitolite SSH private key: /home/redmine/.ssh/redmine_gitolite_admin_id_rsa
- Gitolite SSH public key: /home/redmine/.ssh/redmine_gitolite_admin_id_rsa.pub
- SSH/Gitolite server port: 2222

## Gitolite Global Configuration

- Temporary dir for lock file and data: /home/redmine/active/tmp/redmine_git_hosting
- Git author email: git@redmine.phaenovum.org

## Gitolite Access Configuration

- SSH server domain: redmine.phaenovum.org

## Gitolite Hooks Configuration

Execute once:

- Install hooks !

# Cron

According to [RedmineReceivingEmails and the cronjob #64](https://github.com/docker-library/redmine/issues/64) the redmine image does not contain a cron service. Instead the cron service of the host can be utilized:

```bash
docker container exec --user redmine --workdir /usr/source/redmine/active -i docker_redmine_1 rake redmine:send_reminders project=it-infrastruktur RAILS_ENV=production > /dev/null 2>%1
```

# Logs

View the logs with:

```bash
docker logs -f docker_redmine_1
```

# Known Issues

- SSL certificate paths are hard coded in `passenger.conf`
- `git` username is hard coded in `Dockerfile` and `sudoers.d.redmine`

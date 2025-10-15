FROM geonode/geonode-base:latest-ubuntu-22.04

# copy local geonode src inside container
COPY . /usr/src/geonode/
WORKDIR /usr/src/geonode

COPY wait-for-databases.sh /usr/bin/wait-for-databases
RUN chmod +x /usr/bin/wait-for-databases
RUN chmod +x /usr/src/geonode/tasks.py \
    && chmod +x /usr/src/geonode/entrypoint.sh

COPY celery.sh /usr/bin/celery-commands
RUN chmod +x /usr/bin/celery-commands

COPY celery-cmd /usr/bin/celery-cmd
RUN chmod +x /usr/bin/celery-cmd

RUN yes w | pip install --src /usr/src -r requirements.txt &&\
    yes w | pip install -e .

# Cleanup apt update lists
RUN apt-get autoremove --purge &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

# Export ports
EXPOSE 8000

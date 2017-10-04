#!/usr/bin/env bash

cd ..
docker-compose -p ico -f docker-compose.yml -f docker-compose.dev.yml up $@
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE taskmatebackend;
  CREATE DATABASE taskmatetelegrambot;
  CREATE DATABASE vanillaflowtelegrambot;
EOSQL

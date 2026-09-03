#!/bin/sh

set -eu

psql -X -v ON_ERROR_STOP=1 -f /scripts/seed.sql

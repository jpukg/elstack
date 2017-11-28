#!/bin/bash

: ${ELK_USER:="admin"}
: ${ELK_PASS:="admin"}

echo ">> generating basic auth"
htpasswd -b -c /etc/nginx/htpasswd.users "$ELK_USER" "$ELK_PASS"

exec nginx -g 'daemon off;'
#!/bin/bash
set -e

# input environment variables
# HTTPS, CERT, CERTKEY, HOST, INSECURE, PASSOWRD, HASHED_PASSWORD, PORT

# disallow user to set internal variables via environment
unset -v _CERT _CERTKEY _HOST _AUTH _ADDR _OPTS

if [ "$HTTPS" = "true" ]; then

    if [ -n "$CERT" ]; then
        _CERT=("--cert" "$CERT")

        if [ -n "$CERTKEY" ]; then
            _CERTKEY=("--cert-key" "$CERTKEY")
        fi
    else
        _CERT=("--cert")

        if [ -n "$HOST" ]; then
            _HOST=("--cert-host" "$HOST")
        fi
    fi
fi

if [ "$INSECURE" = "true" ]; then
    _AUTH=("--auth" "none")
elif [ -n "$PASSWORD" ] || [ -n "$HASHED_PASSWORD" ]; then
    _AUTH=("--auth" "password")
else
    _AUTH=("--auth" "password")
fi

if [ -n "$PORT" ]; then
    _ADDR=("--bind-addr" "0.0.0.0:$PORT")
elif [ -n "$HTTPS" ]; then
    _ADDR=("--bind-addr" "0.0.0.0:8443")
else
    _ADDR=("--bind-addr" "0.0.0.0:8080")
fi

_OPTS=("--disable-getting-started-override")

exec code-server ${_CERT[@]} ${_CERTKEY[@]} ${_HOST[@]} ${_AUTH[@]} ${_ADDR[@]} ${_OPTS[@]}

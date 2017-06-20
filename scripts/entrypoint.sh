#!/bin/sh

export PYTHONPATH="app:"

rand_chars() { tr -dc '[:alnum:]'"${*}" </dev/urandom | tr -d ''\''"'; }
gen_key() { rand_chars '[:punct:]' | head -c "${1:-32}"; }
mktemp() { echo "/tmp/tmp.$(rand_chars | head -c8)"; }

config_get_key() {
    python -c 'from app import config; print(config.'"$1"')'
}

get_key() (
    var="$1"
    gend_key="$( gen_key )"
    printf 'New Key!: %s='\''%s'\''\n' "$var" "$gend_key" >&2
    printf "'%s'" "$gend_key"
)

CONFIG_PATH="app/config.py"
# USe the config as a reference for possible variables to override in config.env
POSSIBLE_VARS="$(
    awk 'BEGIN{ FS=" =" } /^(# )?[A-Z_]* =/{ sub("^#[ ]*",""); print $1 }' \
    "${CONFIG_PATH}" | sort | uniq
)"

CONFIG_ID_ENCRYPTION_KEY="$( config_get_key ID_ENCRYPTION_KEY )"
CONFIG_FLASK_SECRET_KEY="$( config_get_key FLASK_SECRET_KEY )"

if [ ! "$CONFIG_ID_ENCRYPTION_KEY" ] && [ ! "$ID_ENCRYPTION_KEY" ] ||
    ( echo "$CONFIG_ID_ENCRYPTION_KEY" | grep -Eq '6\\x80\\x18\\xdc\\xcf' )
then
    ID_ENCRYPTION_KEY="$( get_key ID_ENCRYPTION_KEY )"
fi

if [ ! "$CONFIG_FLASK_SECRET_KEY" ] && [ ! "$FLASK_SECRET_KEY" ] ||
    ( echo "$CONFIG_FLASK_SECRET_KEY" | grep -Eq '\\x90]\\xd4SDI\\xb9h\\x89' )
then
    FLASK_SECRET_KEY="$( get_key FLASK_SECRET_KEY )"
fi

# If nothing was configured, assume postgres container defaults, this way
# Someone can preview the docker-compose.yml setup without generating passwords
[ ! "$DATABASE_HOST" ] && export DATABASE_HOST="'postgres'"
[ ! "$DATABASE_USER" ] && export DATABASE_USER="'postgres'"
[ ! "$DATABASE_PASSWORD" ] && export DATABASE_PASSWORD="'postgres'"
[ ! "$DATABASE_NAME" ] && export DATABASE_NAME="'postgres'"

# Rewrite config.py variables
for env_var in $POSSIBLE_VARS; do
    key="$( eval echo \"\$"${env_var}"\" )"
    if [ "$key" ]; then
        tempfile=$(mktemp)
        awk -v name="$env_var" -v value="$key" \
            '$0 ~ "^"name" = " { $0=name" = "value }1' \
             "${CONFIG_PATH}" > "$tempfile" \
            && cat "$tempfile" > "${CONFIG_PATH}" \
            && rm "$tempfile"
    fi
done

# Output config debug
# sed '/^[ ]*#/d; /^$/d;' "$CONFIG_PATH"

# The until loop is to give postgres a chance if it's the first run and the db
# is still in the process of being created
tries=5
seconds=5
count=0
until python build/build_database.py --create; do
    [ $((count)) -gt $tries ] \
        && { echo "Too many retries, re-check database"; exit 1; } >&2
    echo "Failed to connect to DB, trying again in $seconds second(s)"
    count=$((count+1))
    sleep "$seconds"
done

exec "$@"

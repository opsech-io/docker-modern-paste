FROM alpine

MAINTAINER Michael Gooodwin "mike@mgoodwin.net"

ENV REPO=https://github.com/LINKIWI/modern-paste
ENV APP_DIR=/var/www/modern-paste

# Get runtime stuff - stuff we need all the time
RUN apk --no-cache add -t .runtime \
        python2 py-setuptools py-gunicorn py-psycopg2
        # py2-greenlet py2-gevent mariadb-client-libs

# Get the app and remove extra gitdirs and dependencies
RUN apk --no-cache add -t .git-deps git \
    && git clone --depth 1 --branch=master "$REPO" "$APP_DIR" \
    && cd "$APP_DIR" \
    #``
    # Switch SQLAlchemy to postgres
    #
    && sed -e 's|mysql://|postgres://|' -i app/flask_config.py \
    && git submodule init \
    && git submodule update --recursive \
    && rm -rf .git \
    && apk del .git-deps

WORKDIR "$APP_DIR"

COPY config/modern-paste/config.py app/config.py

# Build step
RUN apk --no-cache add -t .build-deps \
        ruby ruby-rdoc ruby-irb nodejs-npm python2-dev \
        py2-pip mysql-dev git build-base openjdk8-jre \
        shadow bash \
    #
    # Add gunicorn user
    #
    && useradd -Mrd "$APP_DIR" -s /sbin/nologin gunicorn \
    #
    # Build the app
    #
    && export PYTHONPATH="app:" \
    && gem install sass \
    && npm install -g uglify-js \
    && sed -i '/mysql-python/d' requirements.txt \
    && pip install -r requirements.txt \
    && mkdir -p app/static/build/js \
    && mkdir -p app/static/build/css \
    && python build/build_js.py --config-environment \
    && python build/build_css.py --config-environment \
    #
    # Remove extras
    #
    # && rm -rf build \
    && apk del .build-deps

VOLUME /var/www/modern-paste-attachments
COPY scripts/entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh \
    && chown gunicorn . app app/config.py

USER gunicorn
EXPOSE 8000
ENTRYPOINT [ "./entrypoint.sh" ]
CMD [ "gunicorn", "-b :8000", "--chdir=app", "modern_paste:app" ]

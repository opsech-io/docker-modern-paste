FROM alpine

ENV REPO=https://github.com/LINKIWI/modern-paste
ENV APP_DIR=/var/www/modern-paste

# Get runtime stuff - stuff we need all the time
RUN apk --no-cache add -t runtime \
        python2 py-setuptools py-gunicorn py2-greenlet py2-gevent

# Get the damn app, but get rid of the crap
RUN apk --no-cache add -t git-deps git \
    && git clone --depth 1 --branch=master "$REPO" "$APP_DIR" \
    && cd "$APP_DIR" \
    && git submodule init \
    && git submodule update --recursive \
    && rm -rf .git \
    && apk del git-deps

WORKDIR "$APP_DIR"

# Build step
RUN apk --no-cache add -t build-deps \
        ruby ruby-rdoc ruby-irb nodejs-npm python2-dev \
        py2-pip mysql-dev pwgen git build-base openjdk8-jre \
        shadow bash \
    #
    # Add gunicorn user
    #
    && useradd -Mrd "$APP_DIR" -s /sbin/nologin gunicorn \
    #
    # Build the damn thing
    #
    && export PYTHONPATH="app:" \
    && gem install sass \
    && npm install -g uglify-js \
    && pip install -r requirements.txt \
    && mkdir -p app/static/build/js \
    && mkdir -p app/static/build/css \
    && python build/build_js.py --prod \
    && python build/build_css.py --prod \
    #
    # Remove the extra shit
    #
    && rm -rf build \
    && apk del build-deps

USER gunicorn

CMD [ "gunicorn", "-b :8000", "-k gevent", "--chdir=app", "modern_paste:app" ]

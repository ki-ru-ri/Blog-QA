FROM ruby:2.7-alpine AS base

ARG BUNDLER_VERSION=2.2.33
ENV BUNDLER_VERSION=${BUNDLER_VERSION}

ENV LD_LIBRARY_PATH /lib64

RUN apk add --no-cache tzdata bash less build-base nodejs yarn postgresql-dev postgresql-client \
      nano rsync git libc6-compat && \
    gem install bundler -v "${BUNDLER_VERSION}"
WORKDIR /code

COPY Gemfile Gemfile.lock ./
RUN bundle install --retry=7 --jobs="$(getconf _NPROCESSORS_ONLN)"

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

FROM ruby:2.1

RUN apt-get update
RUN apt-get install -y percona-toolkit

COPY . /code/

WORKDIR /code

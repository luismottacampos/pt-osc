FROM ruby:2.2

RUN apt-get update
RUN apt-get install -y percona-toolkit

COPY . /code/

WORKDIR /code

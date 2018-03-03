FROM elixir:1.6-alpine

WORKDIR /opt/app

ENV HOME /opt/app
ENV MIX_HOME=/opt/mix
ENV HEX_HOME=/opt/hex
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

ADD mix.exs mix.lock ./

RUN mix do deps.get, deps.compile

COPY . /opt/app

CMD mix run --no-halt
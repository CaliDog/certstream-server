FROM elixir:1.6-alpine

WORKDIR /opt/app

ENV HOME /opt/app
ENV MIX_HOME=/opt/mix
ENV HEX_HOME=/opt/hex
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

ADD mix.exs ./
ADD mix.lock ./

RUN mix do deps.get, deps.compile

COPY html/dist/ /opt/app/html/dist/
COPY config/ /opt/app/config/

COPY lib /opt/app/lib/

CMD mix run --no-halt

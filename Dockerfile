FROM elixir:1.8-alpine

WORKDIR /opt/app

ENV HOME /opt/app
ENV MIX_HOME=/opt/mix
ENV HEX_HOME=/opt/hex
ENV MIX_ENV=prod

RUN apk add git

RUN mix local.hex --force && mix local.rebar --force

ADD mix.exs ./
ADD mix.lock ./

RUN mix do deps.get, deps.compile

COPY frontend/dist/ /opt/app/frontend/dist/
COPY config/ /opt/app/config/

COPY lib /opt/app/lib/

CMD mix run --no-halt

EXPOSE 80/tcp
EXPOSE 4000/tcp
EXPOSE 4000/udp

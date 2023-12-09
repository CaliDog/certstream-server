# Frontend build
FROM node:20-alpine3.18 as build

WORKDIR /opt/app

COPY frontend ./frontend

WORKDIR /opt/app/frontend

RUN npm install && npm run build && rm -rf node_modules

# Main build
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

COPY --from=build /opt/app/frontend ./frontend
COPY config/ /opt/app/config/

COPY lib /opt/app/lib/

CMD mix run --no-halt

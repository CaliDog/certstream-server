FROM node:20-alpine3.18 as build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install

COPY . .

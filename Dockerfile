FROM nginx:alpine

RUN apk update
ADD https://github.com/gohugoio/hugo/releases/download/v0.40.3/hugo_0.40.3_Linux-64bit.tar.gz /tmp/hugo.tar.gz
RUN tar -zxvf /tmp/hugo.tar.gz
RUN mkdir /src


ADD archetypes /src/archetypes
ADD config.toml /src/
ADD content /src/content
ADD data /src/data
ADD layouts /src/layouts
ADD static /src/static
ADD themes /src/themes

COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /src
RUN /hugo

USER nginx
EXPOSE 8080

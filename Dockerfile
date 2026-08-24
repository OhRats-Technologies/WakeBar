FROM alpine:3.22 AS assets
WORKDIR /src
COPY site/ ./
RUN ./build-assets.sh /src /out

FROM nginx:alpine
COPY site/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=assets /out/ /usr/share/nginx/html/

EXPOSE 80

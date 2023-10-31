FROM node:alpine

WORKDIR /app

COPY . .

# EXPOSE 3000

RUN apk update && apk add --no-cache openssl curl &&\
    apk add --no-cache bash &&\
    chmod +x index.js start.sh server swith web /app &&\
    npm install -r package.json

CMD ["node", "index.js"]

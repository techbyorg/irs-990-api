FROM node:12.16.1-buster

RUN apt-get update && apt-get install -y gdal-bin git python python-pip graphicsmagick imagemagick libcairo2-dev libjpeg-dev libpango1.0-dev libgif-dev librsvg2-dev build-essential

# IRSX with env var support
RUN pip install git+git://github.com/techbyorg/990-xml-reader.git

# Cache dependencies
COPY package-lock.json /tmp/package-lock.json
COPY package.json /tmp/package.json
RUN mkdir -p /opt/app && \
    cd /opt/app && \
    cp /tmp/package-lock.json . && \
    cp /tmp/package.json . && \
    npm install --production --unsafe-perm --loglevel warn

COPY . /opt/app

WORKDIR /opt/app

CMD ["npm", "start"]

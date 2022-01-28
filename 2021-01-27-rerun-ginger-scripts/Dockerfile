ARG GDAL_VER=3.3.2
FROM --platform=linux/amd64 osgeo/gdal:ubuntu-full-$GDAL_VER

ARG PGP_VER=2.3.2

USER root
RUN apt-get update \
    && apt-get install -y \
        build-essential \
        python3-setuptools-scm \
        python3-setuptools \
        libpython3.8-dev \
        python3-rtree \
        python3-scipy \
        python3-shapely \
        cython3 \
        python3-pandas \
        python3-gdal \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade numpy "pygeoprocessing==$PGP_VER"

ADD . /nci

WORKDIR /nci

ENTRYPOINT ["/usr/bin/python"]

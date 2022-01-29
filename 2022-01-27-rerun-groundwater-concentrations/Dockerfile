FROM --platform=linux/amd64 conda/miniconda3

USER root
RUN conda install -c conda-forge pygeoprocessing pandas

ENTRYPOINT ["/usr/local/bin/python"]

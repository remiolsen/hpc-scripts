FROM frolvlad/alpine-miniconda3

LABEL author="Remi-Andre Olsen" \
      description="rapidcuration_extras" \
      maintainer="remi-andre.olsen@scilifelab.se"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/rapidcuration_extras/bin:$PATH

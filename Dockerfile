FROM ubuntu:xenial-20210722

# Used command:
# neurodocker generate docker --base=debian:stretch --pkg-manager=apt
# --ants version=latest method=source --mrtrix3 version=3.0_RC3
# --freesurfer version=6.0.0 method=binaries --fsl version=6.0.1 method=binaries

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bc \
        libtool \
        tar \
        dpkg \
        curl \
        wget \
        unzip \
        gcc \
        git \
        libstdc++6

# SETUP taken from fmriprep:latest, installs C compiler for ANTS
# Prepare environment
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
                    curl \
                    bzip2 \
                    ca-certificates \
                    xvfb \
                    cython3 \
                    build-essential \
                    autoconf \
                    libtool \
                    pkg-config \
                    git && \
    curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -y --no-install-recommends \
                    nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install latest pandoc
# RUN curl -o pandoc-2.2.2.1-1-amd64.deb -sSL "https://github.com/jgm/pandoc/releases/download/2.2.2.1/pandoc-2.2.2.1-1-amd64.deb" && \
#     dpkg -i pandoc-2.2.2.1-1-amd64.deb && \
#     rm pandoc-2.2.2.1-1-amd64.deb

WORKDIR /


ENV FSLDIR="/opt/fsl-6.0.1" \
    PATH="/opt/fsl-6.0.1/bin:$PATH" \
    FSLOUTPUTTYPE="NIFTI_GZ"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           dc \
           file \
           libfontconfig1 \
           libfreetype6 \
           libgl1-mesa-dev \
           libglu1-mesa-dev \
           libgomp1 \
           libice6 \
           libxcursor1 \
           libxft2 \
           libxinerama1 \
           libxrandr2 \
           libxrender1 \
           libxt6 \
           python \
           wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Downloading FSL ..." \
    && wget -q http://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py \
    && chmod 775 fslinstaller.py
RUN /fslinstaller.py -d /opt/fsl-6.0.1 -V 6.0.1 -q

# FSL 6.0.1
# MRtrix3
# Python 3

# MRtrix3
# from https://hub.docker.com/r/neurology/mrtrix/dockerfile
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    python \
    python-numpy \
    libeigen3-dev \
    clang \
    zlib1g-dev \
    libqt4-opengl-dev \
    libgl1-mesa-dev \
    git \
    ca-certificates
RUN mkdir /mrtrix

RUN git clone https://github.com/MRtrix3/mrtrix3.git --branch 3.0.2 /mrtrix
WORKDIR /mrtrix
# Checkout version used in the lab: 20180128
# RUN git checkout f098f097ccbb3e5efbb8f5552f13e0997d161cce
ENV CXX=/usr/bin/clang++
RUN ./configure
RUN ./build
RUN ./set_path
ENV PATH=/mrtrix/bin:$PATH

WORKDIR /

# Installing freesurfer
RUN curl -sSL https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.1.0/freesurfer-linux-centos8_x86_64-7.1.0.tar.gz \
    | tar zxv --no-same-owner -C /opt \
    --exclude='freesurfer/diffusion' \
    --exclude='freesurfer/docs' \
    --exclude='freesurfer/fsfast' \
    --exclude='freesurfer/lib/cuda' \
    --exclude='freesurfer/lib/qt' \
    --exclude='freesurfer/matlab' \
    --exclude='freesurfer/mni/share/man' \
    --exclude='freesurfer/subjects/fsaverage_sym' \
    --exclude='freesurfer/subjects/fsaverage3' \
    --exclude='freesurfer/subjects/fsaverage4' \
    --exclude='freesurfer/subjects/cvs_avg35' \
    --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
    --exclude='freesurfer/subjects/bert' \
    --exclude='freesurfer/subjects/lh.EC_average' \
    --exclude='freesurfer/subjects/rh.EC_average' \
    --exclude='freesurfer/subjects/sample-*.mgz' \
    --exclude='freesurfer/subjects/V1_average' \
    --exclude='freesurfer/trctrain'

# Simulate SetUpFreeSurfer.sh
ENV FSL_DIR="/opt/fsl-6.0.1" \
    OS="Linux" \
    FS_OVERRIDE=0 \
    FIX_VERTEX_AREA="" \
    FSF_OUTPUT_FORMAT="nii.gz" \
    FREESURFER_HOME="/opt/freesurfer"
ENV SUBJECTS_DIR="$FREESURFER_HOME/subjects" \
    FUNCTIONALS_DIR="$FREESURFER_HOME/sessions" \
    MNI_DIR="$FREESURFER_HOME/mni" \
    LOCAL_DIR="$FREESURFER_HOME/local" \
    MINC_BIN_DIR="$FREESURFER_HOME/mni/bin" \
    MINC_LIB_DIR="$FREESURFER_HOME/mni/lib" \
    MNI_DATAPATH="$FREESURFER_HOME/mni/data"
ENV PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    MNI_PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    PATH="$FREESURFER_HOME/bin:$FSFAST_HOME/bin:$FREESURFER_HOME/tktools:$MINC_BIN_DIR:$PATH"

# Installing and setting up miniconda
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh && \
    bash Miniconda3-4.5.11-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.5.11-Linux-x86_64.sh

# Set CPATH for packages relying on compiled libs (e.g. indexed_gzip)
ENV PATH="/usr/local/miniconda/bin:$PATH" \
    CPATH="/usr/local/miniconda/include/:$CPATH" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONNOUSERSITE=1

# add credentials on build
RUN mkdir ~/.ssh && ln -s /run/secrets/host_ssh_key ~/.ssh/id_rsa
# Getting required installation tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libopenblas-base

# Precaching atlases
ENV TEMPLATEFLOW_HOME="/opt/templateflow"
RUN mkdir -p $TEMPLATEFLOW_HOME
RUN pip install --no-cache-dir "templateflow>=0.3.0,<0.4.0a0" && \
    python -c "from templateflow import api as tfapi; \
               tfapi.get('MNI152NLin6Asym', atlas=None); \
               tfapi.get('MNI152NLin2009cAsym', atlas=None); \
               tfapi.get('OASIS30ANTs');" && \
    find $TEMPLATEFLOW_HOME -type d -exec chmod go=u {} + && \
    find $TEMPLATEFLOW_HOME -type f -exec chmod go=u {} +

RUN conda install -y python=3.7.3 \
                     pip=19.1 \
                     libxml2=2.9.8 \
                     libxslt=1.1.32 \
                     graphviz=2.40.1; sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda build purge-all; sync && \
    conda clean -tipsy && sync

RUN pip install --upgrade pip

RUN mkdir tractify
COPY ./ tractify/
RUN cd tractify && pip install .

ENTRYPOINT ["tractify"]


FROM prlprg/r-dyntrace:r-4.0.2

# install additional packages
RUN DEBIAN_FRONTEND=noninteractive \
  apt-get update -yqq && \
  apt-get install -yqq \
    clang \
    gcc-8 \
    g++-8 \
    gdb \
    locales \
    libharfbuzz-dev \
    libfribidi-dev \
    pandoc \
    rr

RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 8 && \
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 8

# install patched version of R-dyntrace
RUN rm -fr $R_DIR $R_DIR_DBG && \
  git clone -b r-4.0.2-signatr https://github.com/fikovnik/R-dyntrace $R_DIR && \
  cd $R_DIR && \
  ./build

# install latest GNU parallel
RUN mkdir parallel && \
  cd parallel && \
  curl http://ftp.gnu.org/gnu/parallel/parallel-latest.tar.bz2 | tar -xjf- --strip 1 && \
  ./configure && \
  make install && \
  mkdir /root/.parallel && \
  touch /root/.parallel/will-cite

# add r user and group
# this is the user that will be used to run the experiments
RUN useradd -u 1000 -m -U -G sudo -s /bin/bash r && \
  echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
  echo "Defaults secure_path=\"$PATH\"" >> /etc/sudoers && \
  touch /home/r/.sudo_as_admin_successful && \
  mkdir /home/r/.parallel && \
  touch /home/r/.parallel/will-cite && \
  mkdir -m 700 /home/r/.ssh

ADD dependencies.txt /tmp
RUN $R_DIR/bin/R -e 'install.packages(readLines("/tmp/dependencies.txt"), repos="cran.r-project.org")'

# install bison
RUN curl https://ftp.gnu.org/gnu/bison/bison-3.5.4.tar.gz | tar -xzf - && \
  cd bison-3.5.4 && \
  ./configure && \
  make -j && \
  make install

# install tastr
RUN git clone https://github.com/PRL-PRG/tastr && \
  make -C tastr build

# install injectr
RUN git clone https://github.com/PRL-PRG/injectr && \
  make -C injectr install

# install contractr
RUN git clone https://github.com/PRL-PRG/contractr && \
  make -C contractr install

# install sxpdb
RUN git clone https://github.com/PRL-PRG/sxpdb && \
  make -C sxpdb install

# install argtracer
RUN git clone https://github.com/PRL-PRG/argtracer && \
  make -C argtracer install

# install generatr
RUN git clone https://github.com/reallyTG/generatr && \
  make -C generatr install

# install runr
RUN git clone https://github.com/PRL-PRG/runr && \
  make -C runr install

# install signatr
RUN git clone https://github.com/PRL-PRG/signatr && \
  make -C signatr install

ADD entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

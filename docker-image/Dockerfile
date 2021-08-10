FROM prlprg/r-dyntrace:r-4.0.2

# install additional packages
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -yqq && \
    apt-get install -yqq \
      gdb \
      locales \
      libharfbuzz-dev \
      libfribidi-dev \
      rr \
  	  flex

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8

# latest GNU parallel
RUN mkdir parallel && \
    cd parallel && \
    curl http://ftp.gnu.org/gnu/parallel/parallel-latest.tar.bz2 | tar -xjf- --strip 1 && \
    ./configure && \
    make install && \
    mkdir /root/.parallel && \
    touch /root/.parallel/will-cite

# install fd
RUN wget -O /tmp/fd.deb https://github.com/sharkdp/fd/releases/download/v8.2.1/fd_8.2.1_amd64.deb && \
  dpkg -i /tmp/fd.deb && \
  rm -f /tmp/fd.deb

# install m4
RUN mkdir m4 && \
    cd m4 && \
    curl https://ftp.gnu.org/gnu/m4/m4-latest.tar.bz2 | tar -xjf- --strip 1 && \
    ./configure && \
    make install

# install bison
RUN mkdir bison && \
    cd bison && \
    curl https://ftp.gnu.org/gnu/bison/bison-3.5.tar.gz | tar -xzf- --strip 1 && \
    ./configure && \
    make install

# install roxygen2 for contractr
RUN Rscript -e "install.packages(\"roxygen2\", repos=\"http://cran.us.r-project.org\")"
RUN Rscript -e "install.packages(\"gtools\", repos=\"http://cran.us.r-project.org\")"

# install tastr for contractr
RUN git clone https://github.com/PRL-PRG/tastr --branch typer-oopsla20 && \
    make -C tastr CXX=g++

# install injectr for contractr
RUN git clone https://github.com/PRL-PRG/injectr --branch typer-oopsla20 && \
    R CMD INSTALL injectr

# install contractr
RUN git clone https://github.com/PRL-PRG/contractr --branch typer-oopsla20 && \
    R CMD INSTALL contractr

ENV R_PROJECT_BASE_DIR="/R" \
    TERM=xterm

RUN useradd -u 1000 -m -U -G sudo -s /bin/bash r && \
  echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
  echo "Defaults secure_path=\"$PATH\"" >> /etc/sudoers && \
  touch /home/r/.sudo_as_admin_successful && \
  mkdir /home/r/.parallel && \
  touch /home/r/.parallel/will-cite

ADD entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

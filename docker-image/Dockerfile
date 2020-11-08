FROM prlprg/r-dyntrace:r-4.0.2

# latest GNU parallel
RUN mkdir parallel && \
    cd parallel && \
    curl http://ftp.gnu.org/gnu/parallel/parallel-latest.tar.bz2 | tar -xjf- --strip 1 && \
    ./configure && \
    make install && \
    mkdir /root/.parallel && \
    touch /root/.parallel/will-cite

ENV R_PROJECT_BASE_DIR="/R" \
    TERM=xterm

RUN useradd -u 1000 -m -U -G sudo -s /bin/bash r && \
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
  touch /home/r/.sudo_as_admin_successful && \
  mkdir /home/r/.parallel && \
  touch /home/r/.parallel/will-cite

ADD entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

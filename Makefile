# saner makefile
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

ifndef R_LIBS
$(error R_LIBS is not set)
endif

# TODO: add support for blacklisting packages (e.g. H2O)

include Makevars

R_BIN             := $(R_DIR)/bin/R
CRAN_LOCAL_MIRROR := file://$(CRAN_DIR)
CRAN_SRC_DIR      := $(CRAN_DIR)/extracted
CRAN_ZIP_DIR      := $(CRAN_DIR)/src/contrib
SCRIPTS_DIR       := $(PROJECT_BASE_DIR)/scripts
RUNR_DIR          := $(PROJECT_BASE_DIR)/runr
RUNR_TASKS_DIR    := $(RUNR_DIR)/inst/tasks

# this is where the results shoud go to
RUN_DIR := $(PROJECT_BASE_DIR)/run

# This file contains a list of all packages we want to include.
PACKAGES := packages.txt

# the number of jobs to run in parallel
# it is used for GNU parallel and for Ncpus parameter in install.packages
JOBS          ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc -a 2>/dev/null || grep -c processor /proc/cpuinfo 2>/dev/null || echo 1)
# TODO: do not rely on GNU parallel timeout, use timeout binary
TIMEOUT       ?= 35m

# tools
MAP				:= $(RUNR_DIR)/inst/map.sh -j $(JOBS) $(MAP_EXTRA)
R					:= R_LIBS=$(LIBRARY_DIR) $(R_DIR)/bin/R
RSCRIPT		:= R_LIBS=$(LIBRARY_DIR) $(R_DIR)/bin/Rscript
MERGE     := $(RSCRIPT) $(RUNR_DIR)/inst/merge-files.R
ROLLBACK  := $(SCRIPTS_DIR)/rollback.sh
CAT       := $(SCRIPTS_DIR)/cat.R

# A template that is used to wrap the extracted runnable code from packages.
WRAP_TEMPLATE_FILE := $(SCRIPTS_DIR)/wrap-template.R

########################################################################
# TASKS OUTPUTS
########################################################################

# runnable code
EXTRACTED_CODE_DIR   := $(RUN_DIR)/extracted-code
EXTRACTED_CODE_CSV   := $(EXTRACTED_CODE_DIR)/runnable-code.csv
EXTRACTED_CODE_STATS := $(EXTRACTED_CODE_DIR)/parallel.csv

# tracing runnable code
WRAPPED_CODE_DIR   := $(RUN_DIR)/wrapped-code
WRAPPED_CODE_CSV   := $(WRAPPED_CODE_DIR)/runnable-code.csv
WRAPPED_CODE_STATS := $(WRAPPED_CODE_DIR)/parallel.csv

# run the extracted code - for sanity checking
RUN_CODE_DIR   := $(RUN_DIR)/run-code
RUN_CODE_STATS := $(RUN_CODE_DIR)/parallel.csv

# tracing - getting the db
TRACE_DIR   := $(RUN_DIR)/trace
TRACE_STATS := $(TRACE_DIR)/parallel.csv

########################################################################
# HELPERS                                                              #
########################################################################

txtbold := $(shell tput bold)
txtred  := $(shell tput setaf 2)
txtsgr0 := $(shell tput sgr0)

define LOG
	@echo -n "$(txtbold)"
	@echo "----------------------------------------------------------------------"
	@echo "=> $(txtred)$(1)$(txtsgr0)"
	@echo -n "$(txtbold)"
	@echo "----------------------------------------------------------------------"
	@echo -n "$(txtsgr0)"
endef

define PKG_INSTALL_FROM_FILE
	$(R) --quiet --no-save -e 'install.packages(if (Sys.getenv("FORCE_INSTALL")=="1") readLines("$(1)") else setdiff(readLines("$(1)"), installed.packages()), dependencies=TRUE, destdir="$(CRAN_ZIP_DIR)", repos="$(CRAN_MIRROR)", Ncpus=$(JOBS))'
	find $(CRAN_ZIP_DIR) -name "*.tar.gz" | parallel --bar --workdir CRAN/extracted tar xfz
endef

define CHECK_REPO
	@if [ ! -d "$(notdir $(1))" ]; then echo "Missing $(1) repository, please run: git clone https://github.com/$(1)"; exit 1; fi
endef

define CLONE_REPO
	[ -d "$(notdir $(1))" ] || git clone https://github.com/$(1)
endef

define INFO
  @echo "$(1)=$($(1))"
endef

########################################################################
# TARGETS                                                              #
########################################################################

$(EXTRACTED_CODE_STATS): $(PACKAGES)
	$(call LOG,EXTRACTING CODE)
	-$(MAP) -t $(TIMEOUT) --override -f $< -o $(@D) -e $(RUNR_TASKS_DIR)/package-runnable-code.R \
    -- $(CRAN_DIR)/extracted/{1}

$(EXTRACTED_CODE_CSV): $(EXTRACTED_CODE_STATS)
	$(call LOG,MERGING $(@F))
	$(MERGE) --in $(@D) --csv-cols "ccciii" --key "package" --key-use-dirname $(@F)

$(WRAPPED_CODE_STATS): $(PACKAGES)
	$(call LOG,WRAPPING CODE)
	-$(MAP) -t $(TIMEOUT) --override -f $< -o $(@D) -e $(RUNR_TASKS_DIR)/package-runnable-code.R \
    -- $(CRAN_DIR)/extracted/{1} --wrap $(WRAP_TEMPLATE_FILE)

$(WRAPPED_CODE_CSV): $(WRAPPED_CODE_STATS)
	$(call LOG,MERGING $(@F))
	$(MERGE) --in $(@D) --csv-cols "ccciii" --key "package" --key-use-dirname $(@F)

.PRECIOUS: $(RUN_CODE_STATS)
$(RUN_CODE_STATS): $(EXTRACTED_CODE_CSV)
	$(call LOG,RUNNING)
	-$(CAT) -d '/' -c package,file --no-header $< | \
    $(MAP) -f - -o $(@D) -e $(SCRIPTS_DIR)/run-r-file.sh --no-exec-wrapper \
    -- -t $(TIMEOUT) $(EXTRACTED_CODE_DIR)/{1}

.PRECIOUS: $(TRACE_STATS)
$(TRACE_STATS): $(WRAPPED_CODE_CSV)
	$(call LOG,TRACING)
	-$(CAT) -d '/' -c package,file --no-header $< | \
    $(MAP) -f - -o $(@D) -e $(SCRIPTS_DIR)/run-r-file.sh --no-exec-wrapper \
    -- -t $(TIMEOUT) $(WRAPPED_CODE_DIR)/{1}

.PHONY: extract-code
extract-code:
	$(ROLLBACK) $(EXTRACTED_CODE_DIR)
	@$(MAKE) $(EXTRACTED_CODE_CSV) $(EXTRACTED_CODE_STATS)

.PHONY: run-code
run-code:
	$(ROLLBACK) $(RUN_CODE_DIR)
	@$(MAKE) $(RUN_CODE_STATS)

.PHONY: wrap-code
wrap-code:
	$(ROLLBACK) $(WRAPPED_CODE_DIR)
	@$(MAKE) $(WRAPPED_CODE_CSV) $(WRAPPED_CODE_STATS)

.PHONY: run
run:
	$(ROLLBACK) $(RUN_CODE_DIR)
	@$(MAKE) $(RUN_CODE_STATS)

.PHONY: trace
trace:
	$(ROLLBACK) $(TRACE_DIR)
	@$(MAKE) $(TRACE_STATS)

.PHONY: install-packages
install-packages:
	$(call PKG_INSTALL_FROM_FILE,$(PACKAGES))

########################################################################
# SIGNATR dependencies                                                 #
########################################################################

$(LIBRARY_DIR):
	mkdir -p $@

$(CRAN_ZIP_DIR):
	mkdir -p $@

$(CRAN_SRC_DIR):
	mkdir -p $@

.PHONY: libs-dependencies
libs-dependencies: $(LIBRARY_DIR) $(CRAN_ZIP_DIR) $(CRAN_SRC_DIR)
	$(call LOG,Installing lib dependencies: $@)
	$(call PKG_INSTALL_FROM_FILE,dependencies.txt)

.PHONY: argtracer
argtracer:
	$(call LOG,Installing library: $@)
	$(call CHECK_REPO,PRL-PRG/argtracer)
	cd $@ && \
    rm -rf src/*.o src/*.so && \
    R CMD INSTALL .

.PHONY: instrumentr
instrumentr:
	$(call LOG,Installing library: $@)
	$(call CHECK_REPO,PRL-PRG/instrumentr)
	cd $@ && \
    make clean install


.PHONY: record
record:
	$(call LOG,Installing library: $@)
	$(call CHECK_REPO,yth/record-dev)
	cd record-dev/record && \
    rm -rf src/*.o src/*.so && \
    R CMD INSTALL .

.PHONY: runr
runr:
	$(call LOG,Installing library: $@)
	$(call CHECK_REPO,PRL-PRG/runr)
	cd $@ && \
		make clean install

.PHONY: libs
libs: libs-dependencies record instrumentr argtracer runr

.PHONY: envir
envir:
	$(call INFO,CRAN_LOCAL_MIRROR)
	$(call INFO,CRAN_DIR)
	$(call INFO,CURDIR)
	$(call INFO,LIBRARY_DIR)
	$(call INFO,R_BIN)
	$(call INFO,RUN_DIR)
	$(call INFO,JOBS)
	$(call INFO,TIMEOUT)

.PHONY: clone
clone:
	$(call CLONE_REPO,hyeyoungshin/argtracer)
	$(call CLONE_REPO,PRL-PRG/instrumentr)
	$(call CLONE_REPO,yth/record-dev)
	$(call CLONE_REPO,PRL-PRG/runr)

########################################################################
# DOCKER                                                               #
########################################################################

DOCKER_SHELL_CONTAINER_NAME := $$USER-signatr-shell
DOCKER_IMAGE_NAME := prlprg/project-signatr

SHELL_CMD ?= bash

.PHONY: shell
shell: $(LIBRARY_DIR) $(CRAN_ZIP_DIR) $(CRAN_SRC_DIR)
	docker run \
    --rm \
    --name $(DOCKER_SHELL_CONTAINER_NAME)-$$(openssl rand -hex 2) \
    --privileged \
    -ti \
    -v "$(CURDIR):$(CURDIR)" \
    -v $$(readlink -f $(CRAN_DIR)):$(CRAN_DIR) \
    -v $$(readlink -f $(LIBRARY_DIR)):$(LIBRARY_DIR) \
    -e USER_ID=$$(id -u) \
    -e GROUP_ID=$$(id -g) \
    -e R_LIBS=$(LIBRARY_DIR) \
    -e TZ=Europe/Prague \
    -w $(CURDIR) \
    $(DOCKER_IMAGE_NAME) \
    $(SHELL_CMD)

.PHONY: rstudio
rstudio:
	if [ -z "$$PORT" ]; then echo "Missing PORT"; exit 1; fi
	docker run \
    --rm \
    --name "$$USER-signatr-rstudio-$$PORT" \
    -d \
    -p "$$PORT:8787" \
    -v "$(CURDIR):$(CURDIR)" \
    -e USERID=$$(id -u) \
    -e GROUPID=$$(id -g) \
    -e ROOT=true \
    -e DISABLE_AUTH=true \
    $(DOCKER_RSTUDIO_IMAGE_NAME)

.PHONY: docker-image
docker-image:
	$(MAKE) -C docker-image

.PHONY: httpd
httpd:
	docker run \
    --rm \
    -d \
    --name signatr-httpd \
    -p 80:80 \
    -v $(PROJECT_BASE_DIR):/usr/local/apache2/htdocs$(PROJECT_BASE_DIR) \
    httpd:2.4

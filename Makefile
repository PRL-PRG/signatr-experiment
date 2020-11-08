# saner makefile
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

# extra parameters
JOBS          ?= 16
PACKAGES_FILE ?= packages-100.txt
TIMEOUT       ?= 30m

R_PROJECT_BASE_DIR ?= /R

# environment
R_DIR              := $(R_PROJECT_BASE_DIR)/R-dyntrace
PACKAGES_SRC_DIR   := $(R_PROJECT_BASE_DIR)/CRAN/extracted
PACKAGES_ZIP_DIR   := $(R_PROJECT_BASE_DIR)/CRAN/src/contrib
CRAN_LOCAL_MIRROR  := file://$(R_PROJECT_BASE_DIR)/CRAN
R_BIN              := $(R_DIR)/bin/R

RUNR_DIR           := $(CURDIR)/runr
RUNR_TASKS_DIR     := $(RUNR_DIR)/inst/tasks
SCRIPTS_DIR        := $(CURDIR)/scripts
RUN_DIR            := $(CURDIR)/run
DATA_DIR           := $(CURDIR)/data
SIGNATR_DIR        := $(CURDIR)/signatr

PACKAGE_METADATA_DIR := $(RUN_DIR)/package-metadata

# variables
MERGE_CSV := $(R_DIR)/bin/Rscript $(RUNR_DIR)/inst/merge-csv.R
ON_EACH_PACKAGE := $(MAKE) on-each-package

# runs
PACKAGE_COVERAGE_CSV   := $(RUN_DIR)/package-coverage/coverage.csv
PACKAGE_COVERAGE_STATS := $(RUN_DIR)/package-coverage/task-stats.csv

PACKAGE_CODE_SIGNATR_CSV   := $(RUN_DIR)/package-code-signatr/runnable-code.csv
PACKAGE_CODE_SIGNATR_STATS := $(RUN_DIR)/package-code-signatr/task-stats.csv
SIGNATR_GBOV_RUN_CSV       := $(RUN_DIR)/signatr-gbov/run.csv
SIGNATR_GBOV_STATS         := $(RUN_DIR)/signatr-gbov/task-stats.csv

PACKAGE_FUNCTIONS_CSV  := $(PACKAGE_METADATA_DIR)/functions.csv
PACKAGE_METADATA_CSV   := $(PACKAGE_METADATA_DIR)/metadata.csv
PACKAGE_REVDEPS_CSV    := $(PACKAGE_METADATA_DIR)/revdeps.csv
PACKAGE_SLOC_CSV       := $(PACKAGE_METADATA_DIR)/sloc.csv
PACKAGE_METADATA_FILES := $(PACKAGE_FUNCTIONS_CSV) $(PACKAGE_METADATA_CSV) $(PACKAGE_REVDEPS_CSV) $(PACKAGE_SLOC_CSV)
PACKAGE_METADATA_STATS := $(PACKAGE_METADATA_DIR)/task-stats.csv

.PHONY: \
  lib \
	libs \
  on-each-package \
  package-coverage \
  package-metadata \
  package-code-signatr \
  signatr-gbov

lib/%:
	R CMD INSTALL $*

libs: lib/injectr lib/instrumentr lib/runr lib/signatr

$(PACKAGE_CODE_SIGNATR_CSV) $(PACKAGE_CODE_SIGNATR_STATS): export OUTPUT_DIR=$(@D)
$(PACKAGE_CODE_SIGNATR_CSV) $(PACKAGE_CODE_SIGNATR_STATS):
	$(ON_EACH_PACKAGE) TASK=$(SIGNATR_DIR)/inst/package-runnable-code-signatr.R
	$(MERGE_CSV) "$(OUTPUT_DIR)" $(@F) $(notdir $(PACKAGE_CODE_SIGNATR_STATS))

$(SIGNATR_GBOV_RUN_CSV) $(SIGNATR_GBOV_STATS): $(PACKAGE_CODE_SIGNATR_CSV)
$(SIGNATR_GBOV_RUN_CSV) $(SIGNATR_GBOV_STATS): export OUTPUT_DIR=$(@D)
$(SIGNATR_GBOV_RUN_CSV) $(SIGNATR_GBOV_STATS): export START_XVFB=1
$(SIGNATR_GBOV_RUN_CSV) $(SIGNATR_GBOV_STATS):
	$(ON_EACH_PACKAGE) R_DIR=$(RDT_DIR) TASK=$(RUNR_TASKS_DIR)/run-extracted-code.R ARGS="$(dir $(PACKAGE_CODE_SIGNATR_CSV))/{1/}"
	$(MERGE_CSV) "$(OUTPUT_DIR)" $(@F) $(notdir $(SIGNATR_GBOV_STATS))

$(PACKAGE_COVERAGE_CSV) $(PACKAGE_COVERAGE_STATS): export OUTPUT_DIR=$(@D)
$(PACKAGE_COVERAGE_CSV) $(PACKAGE_COVERAGE_STATS): export RUNR_PACKAGE_COVERAGE_TYPE=all
$(PACKAGE_COVERAGE_CSV) $(PACKAGE_COVERAGE_STATS):
	$(ON_EACH_PACKAGE) TASK=$(RUNR_TASKS_DIR)/package-coverage.R
	$(MERGE_CSV) "$(OUTPUT_DIR)" $(@F) $(notdir $(PACKAGE_COVERAGE_STATS))

$(PACKAGE_METADATA_FILES) $(PACKAGE_METADATA_STATS): export OUTPUT_DIR=$(@D)
$(PACKAGE_METADATA_FILES) $(PACKAGE_METADATA_STATS):
	$(ON_EACH_PACKAGE) TASK=$(RUNR_TASKS_DIR)/package-metadata.R
	$(MERGE_CSV) "$(@D)" task-stats.csv functions.csv metadata.csv revdeps.csv sloc.csv

package-coverage: $(PACKAGE_COVERAGE_CSV) $(PACKAGE_COVERAGE_STATS)
package-metadata: $(PACKAGE_METADATA_FILES) $(PACKAGE_METADATA_STATS)
package-code-signatr: $(PACKAGE_CODE_SIGNATR_CSV) $(PACKAGE_CODE_SIGNATR_STATS)
signatr-gbov: $(SIGNATR_GBOV_RUN_CSV) $(SIGNATR_GBOV_STATS)

on-each-package:
	@[ "$(TASK)" ] || ( echo "*** Undefined TASK"; exit 1 )
	@[ -x "$(TASK)" ] || ( echo "*** $(TASK): no such file"; exit 1 )
	@[ "$(OUTPUT_DIR)" ] || ( echo "*** Undefined OUTPUT_DIR"; exit 1 )
	-if [ -n "$(START_XVFB)" ]; then  \
     nohup Xvfb :6 -screen 0 1280x1024x24 >/dev/null 2>&1 & \
     export DISPLAY=:6; \
  fi; \
  export R_TESTS=""; \
  export R_BROWSER="false"; \
  export R_PDFVIEWER="false"; \
  export R_BATCH=1; \
  export NOT_CRAN="true"; \
  echo "*** DISPLAY=$$DISPLAY"; \
  echo "*** PATH=$$PATH"; \
  echo "*** R_LIBS=$$R_LIBS"; \
  mkdir -p "$(OUTPUT_DIR)"; \
  export PATH=$$R_DIR/bin:$$PATH; \
  parallel \
    -a $(PACKAGES_FILE) \
    --bar \
    --env PATH \
    --jobs $(JOBS) \
    --results "$(OUTPUT_DIR)/parallel.csv" \
    --tagstring "$(notdir $(TASK)) - {/}" \
    --timeout $(TIMEOUT) \
    --workdir "$(OUTPUT_DIR)/{/}/" \
    $(RUNR_DIR)/inst/run-task.sh \
      $(TASK) "$(PACKAGES_SRC_DIR)/{1/}" $(ARGS)

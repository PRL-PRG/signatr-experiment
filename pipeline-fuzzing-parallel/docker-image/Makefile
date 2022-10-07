# saner makefile
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

DOCKER_IMAGE_NAME := prlprg/sle22-signatr

.PHONY: all
all: image

.PHONY: image
image:
	docker build --rm -t $(DOCKER_IMAGE_NAME) .

.PHONY: upload
upload: image
	docker push $(DOCKER_IMAGE_NAME)

BASE_DIR:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))

include $(BASE_DIR)/../Makevars

.PHONY: all
all: image

.PHONY: image
image:
	docker build \
    --rm \
    -t $(DOCKER_IMAGE_NAME) \
    .

.PHONY: upload
upload: image
	docker push $(DOCKER_IMAGE_NAME)

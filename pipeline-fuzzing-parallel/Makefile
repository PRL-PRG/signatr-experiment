BUDGET := 5000
BASE_DIR := data

.PHONY: cluster

cluster:
	ssh -C -o ServerAliveInterval=30 -o ControlMaster=yes -o ControlPath=ssh-%h -fN prl3
	ssh -C -o ServerAliveInterval=30 -o ControlMaster=yes -o ControlPath=ssh-%h -fN prl4

type:

sync-fuzz:
	rsync -avh --progress 'prl4:signatr/signatr-experiment/pipeline-fuzzing-parallel/data/fuzz/' 'data/fuzz'

BASE_DIR := data

.PHONY: cluster

cluster:
	ssh -C -o ServerAliveInterval=30 -o ControlMaster=yes -o ControlPath=ssh-%h -fN prl3
	ssh -C -o ServerAliveInterval=30 -o ControlMaster=yes -o ControlPath=ssh-%h -fN prl4

.PHONY: report
report:
	R -e 'rmarkdown::render("report.Rmd")'

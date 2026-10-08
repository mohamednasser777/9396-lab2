.PHONY: antivirus restore prepare
DIR ?= ./dir
MALICIOUS_DIR ?= ./malicious_dir
TIME_INTERVAL ?= 5
antivirus: prepare
	./antivirusd.sh "$(DIR)" "$(MALICIOUS_DIR)" $(TIME_INTERVAL)

restore: prepare 
	./restore.sh "$(DIR)" "$(MALICIOUS_DIR)"

prepare:
	mkdir -p "$(MALICIOUS_DIR)"

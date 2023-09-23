.PHONY: help
help:  ## Show this help message
	@grep -E -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: fmt
fmt:  ## Format all files
	packer fmt .

.PHONY: build
build:  ## Build all images
	packer build .

.PHONY: clean
clean:  ## Remove all generated files
	rm -vf *.ign $(MANIFEST)

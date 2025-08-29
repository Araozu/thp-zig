.PHONY: build release install clean

# Default target
all: build

# Build debug version
build:
	zig build -Djson=true

# Build release version
release:
	zig build -Doptimize=ReleaseFast -Djson=true

# Install the binary to /usr/bin
install: release
	@echo "Installing to /usr/bin (requires sudo)"
	sudo cp zig-out/bin/thp /usr/bin/thp
	@echo "Installed to /usr/bin/thp"

# Clean build artifacts
clean:
	rm -rf zig-out

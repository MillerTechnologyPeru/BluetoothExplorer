# Build the Battery Level plugin and install it into the app's bundled plugins.
#
# Requires the Embedded Swift WASM SDK:
#   swift sdk install <swift-<version>_wasm-embedded artifact bundle URL>
# and binaryen for wasm-opt (brew install binaryen).

SWIFT_SDK ?= swift-6.3.3-RELEASE_wasm-embedded
PRODUCT   := GATTObjectTransfer
BUILT     := .build/wasm32-unknown-wasip1/release/$(PRODUCT).wasm
INSTALL   := ../../../Sources/BluetoothExplorerPluginEngine/Plugins
MODULE    := gatt-object-transfer.wasm
MANIFEST  := $(INSTALL)/gatt-object-transfer.bleplugin.json

.PHONY: build opt install clean

build:
	swift build -c release --swift-sdk $(SWIFT_SDK) --product $(PRODUCT)

opt: build
	wasm-opt -Oz --enable-bulk-memory --enable-sign-ext $(BUILT) -o $(MODULE)

# Install the optimized module and refresh the manifest's sha256.
install: opt
	cp $(MODULE) $(INSTALL)/$(MODULE)
	@HASH=$$(shasum -a 256 $(INSTALL)/$(MODULE) | awk '{print $$1}'); \
	  /usr/bin/sed -i '' -E "s/\"sha256\" : \"[0-9a-f]*\"/\"sha256\" : \"$$HASH\"/; s/\"sha256\": \"[0-9a-f]*\"/\"sha256\": \"$$HASH\"/" $(MANIFEST); \
	  echo "installed $(MODULE) sha256=$$HASH"

clean:
	rm -rf .build $(MODULE)

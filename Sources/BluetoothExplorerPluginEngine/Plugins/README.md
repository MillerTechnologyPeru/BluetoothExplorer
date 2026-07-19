# Bundled Plugins

Each bundled plugin is a `<name>.wasm` module paired with a `<name>.bleplugin.json` manifest.
These are copied verbatim into the app bundle (and the Android APK) and loaded at launch by
`PluginManager.loadBundledPlugins()`.

The modules here are build artifacts. Their source lives in `PluginSDK/Examples/`, written in
Embedded Swift against `BLEPluginSDK`. To rebuild and reinstall one:

```sh
cd PluginSDK/Examples/BatteryLevel
make install     # builds for wasm32, runs wasm-opt -Oz, copies here, refreshes the manifest sha256
```

See `Documentation/PluginABI.md` for the ABI and `PluginSDK/README.md` for authoring.

# Bundled Plugins

Each bundled plugin is a `<name>.wasm` module paired with a `<name>.bleplugin.json` manifest.
These are copied verbatim into the app bundle (and the Android APK) and loaded at launch by
`PluginManager.loadBundledPlugins()`.

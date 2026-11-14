{
  "runtime": { "version": "LuaJIT" },
  "workspace": {
    "ignoreGlobs": ["**/hashlib/pure_sha.lua"],
    "library": [
      "../../../elxosc/lib",
      "../../../elxosc/player",
      "../../../elxosc/define",
      "../../../elxosc/host",
      "generated/elxosc.lua",
      "../../../elxlib/elxlibs"
    ],
    "packages": [
      { "path": "../../../elxosc/lib" },
      { "path": "../../../elxosc" },
      { "path": "../../../elxlib" }
    ]
  }
}

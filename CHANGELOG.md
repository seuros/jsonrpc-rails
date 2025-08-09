# Changelog

## [0.5.4](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.5.3...jsonrpc-rails/v0.5.4) (2025-08-09)


### Bug Fixes

* resolve Rack::Lint compatibility issue with input stream rewind ([#13](https://github.com/seuros/jsonrpc-rails/issues/13)) ([0ec0f28](https://github.com/seuros/jsonrpc-rails/commit/0ec0f280e1b3b71ad3a38f1d961fbfe073aab38b))

## [0.5.3](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.5.2...jsonrpc-rails/v0.5.3) (2025-07-03)


### Bug Fixes

* json-rpc expect the id to return with the error. ([c5eff42](https://github.com/seuros/jsonrpc-rails/commit/c5eff42fbbdeb34e1267c04541d20b58fcb541ba))

## [0.5.2](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.5.1...jsonrpc-rails/v0.5.2) (2025-06-29)


### Bug Fixes

* properly handle Response initialization with nil result values ([#10](https://github.com/seuros/jsonrpc-rails/issues/10)) ([2f8e5ac](https://github.com/seuros/jsonrpc-rails/commit/2f8e5ace81c9fb665dccfb3783d4d4af63bb52c0))

## [0.5.1](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.5.0...jsonrpc-rails/v0.5.1) (2025-05-10)


### Bug Fixes

* rename jsonrpc to jsonrpc_params ([abf585c](https://github.com/seuros/jsonrpc-rails/commit/abf585cfa7d57bf70381e0248f2a8f478b18fd47))

## [0.5.0](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.4.0...jsonrpc-rails/v0.5.0) (2025-05-10)


### Features

* add JSON-RPC response rendering methods and tests ([#7](https://github.com/seuros/jsonrpc-rails/issues/7)) ([45209e7](https://github.com/seuros/jsonrpc-rails/commit/45209e742c4de1508a5862334fd4d23e3316cd0e))

## [0.4.0](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.3.1...jsonrpc-rails/v0.4.0) (2025-05-10)


### Features

* return proper data objects ([#5](https://github.com/seuros/jsonrpc-rails/issues/5)) ([ebd9caf](https://github.com/seuros/jsonrpc-rails/commit/ebd9caf2596ab5f4bc23bdea21764be0d5cd3982))

## [0.3.1](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.3.0...jsonrpc-rails/v0.3.1) (2025-05-09)


### Bug Fixes

* set version file ([6023d71](https://github.com/seuros/jsonrpc-rails/commit/6023d71d93bd9b7e5f9ce6e947ce147a77f68418))

## [0.3.0](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails/v0.2.0...jsonrpc-rails/v0.3.0) (2025-05-09)


### Features

* make Validator opt-in by path ([#2](https://github.com/seuros/jsonrpc-rails/issues/2)) ([ea7eab6](https://github.com/seuros/jsonrpc-rails/commit/ea7eab69e6fe0be1d18fb574099fd461b41ac7cc))

## [0.2.0](https://github.com/seuros/jsonrpc-rails/compare/jsonrpc-rails-v0.1.1...jsonrpc-rails/v0.2.0) (2025-04-28)


### Features

* Refine middleware validation trigger logic ([be6617b](https://github.com/seuros/jsonrpc-rails/commit/be6617b0a2bb77c9ba9335ded31e5b2b58657d7e))
* rename namespace ([c7cde30](https://github.com/seuros/jsonrpc-rails/commit/c7cde30532ead66ea9c54496d6015732b3e1553d))


### Bug Fixes

* change to symbol (:"jsonrpc.payload") to dodge string keys stepping on each other. ([cf0582f](https://github.com/seuros/jsonrpc-rails/commit/cf0582f35b1779ea4f30d78aadd7a18522d730eb))
* rewind using env['rack.input'] ([08c8891](https://github.com/seuros/jsonrpc-rails/commit/08c8891e379f28e634a930c3b70e7a3aa204493f))
* The spec says the number type “MUST NOT contain fractions”. ([460e100](https://github.com/seuros/jsonrpc-rails/commit/460e100c54b5797c76eb666138bccbf66116d578))

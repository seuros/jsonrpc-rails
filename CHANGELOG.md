# Changelog

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

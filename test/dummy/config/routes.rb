Rails.application.routes.draw do
  get "/test", to: "testing#index"
  get "/error_symbol", to: "testing#error_symbol"
  get "/error_symbol_override", to: "testing#error_symbol_with_override"
  get "/error_code", to: "testing#error_code"
  get "/error_code_override", to: "testing#error_code_with_override"

  # Route for testing JSON-RPC POST requests via middleware
  post "/rpc", to: "testing#rpc_endpoint"
end

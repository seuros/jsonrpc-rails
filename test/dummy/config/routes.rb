# frozen_string_literal: true

Rails.application.routes.draw do
  get "/test", to: "testing#index"
  get "/error_symbol", to: "testing#error_symbol"
  get "/error_symbol_override", to: "testing#error_symbol_with_override"
  get "/error_code", to: "testing#error_code"
  get "/error_code_override", to: "testing#error_code_with_override"

  get "/render_response", to: "testing#render_response"
  get "/render_notification", to: "testing#render_notification"
  get "/render_batch", to: "testing#render_batch"

  # Route for testing JSON-RPC POST requests via middleware
  post "/rpc", to: "testing#rpc_endpoint"
  post "/api/v1/rpc", to: "testing#rpc_endpoint"
  post "/rpc/private/echo", to: "testing#rpc_endpoint"
end

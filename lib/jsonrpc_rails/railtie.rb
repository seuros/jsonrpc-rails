require_relative "middleware/validator"

module JSON_RPC_Rails
  # Use Rails::Railtie to integrate with the Rails application
  class Railtie < Rails::Railtie
    # Insert the JSON-RPC Validator middleware early in the stack.
    # Inserting before Rack::Sendfile, which is typically present early in the stack.
    initializer "jsonrpc-rails.add_validator_middleware" do |app|
      app.middleware.use JSON_RPC_Rails::Middleware::Validator
    end

    initializer "jsonrpc-rails.add_renderers" do
      ActiveSupport.on_load(:action_controller) do
        ActionController::Renderers.add :jsonrpc do |obj, options|
          # Use the Response class to build the payload
          response_id = options[:id] # ID is required for Response
          error_input = options[:error] # Can be nil, Symbol, Hash, or JsonRpcError

          begin
            response_obj = if error_input
                             # If error is true, treat obj as the error details
                             # (This matches the original logic's assumption)
                             JSON_RPC::Response.new(id: response_id, error: obj)
            else
                             # Otherwise, treat obj as the result
                             JSON_RPC::Response.new(id: response_id, result: obj)
            end
            response_payload = response_obj.to_h
          rescue ArgumentError => e
            # Handle cases where Response initialization fails (e.g., invalid id/result/error combo)
            # Respond with an Internal Error according to JSON-RPC spec
            internal_error = JSON_RPC::JsonRpcError.new(:internal_error, message: "Server error generating response: #{e.message}")
            response_payload = { jsonrpc: "2.0", error: internal_error.to_h, id: response_id }
            # Consider logging the error e.message
          rescue JSON_RPC::JsonRpcError => e
            # Handle specific JsonRpcError during Response processing (e.g., invalid error symbol)
            response_payload = { jsonrpc: "2.0", error: e.to_h, id: response_id }
            # Consider logging the error e.message
          end


          # Set the proper MIME type and convert the hash to JSON.
          self.content_type ||= Mime[:json]
          self.response_body = response_payload.to_json
        end
      end
    end
  end
end

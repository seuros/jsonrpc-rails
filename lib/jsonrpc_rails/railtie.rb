require_relative "middleware/validator"

module JSONRPC_Rails
  # Use Rails::Railtie to integrate with the Rails application
  class Railtie < Rails::Railtie
    config.jsonrpc_rails = ActiveSupport::OrderedOptions.new
    config.jsonrpc_rails.validated_paths = [] # By default, we inject it into the void.
    # Insert the JSON-RPC Validator middleware early in the stack.
    initializer "jsonrpc-rails.add_validator_middleware" do |app|
      app.middleware.use JSONRPC_Rails::Middleware::Validator
    end

    initializer "jsonrpc-rails.add_renderers" do
      ActiveSupport.on_load(:action_controller) do
        ActionController::Renderers.add :jsonrpc do |obj, options|
          # Use the Response class to build the payload
          response_id = options[:id] # ID is required for Response
          error_input = options[:error] # Can be nil, Symbol, Hash, or JsonRpcError
          payload_obj = obj # The main object passed to render

          begin
            response_obj = case error_input
            when Symbol
                             # Build error from symbol, allowing overrides from payload_obj
                             message_override = payload_obj.is_a?(Hash) ? payload_obj[:message] : nil
                             data_override = payload_obj.is_a?(Hash) ? payload_obj[:data] : nil
                             error_hash = JSON_RPC::JsonRpcError.build(error_input, message: message_override, data: data_override)
                             JSON_RPC::Response.new(id: response_id, error: error_hash)
            when Integer
                             # Build error from numeric code, allowing overrides from payload_obj
                             error_code = error_input
                             default_details = JSON_RPC::JsonRpcError.find_by_code(error_code)
                             message_override = payload_obj.is_a?(Hash) ? payload_obj[:message] : nil
                             data_override = payload_obj.is_a?(Hash) ? payload_obj[:data] : nil
                             error_hash = {
                               code: error_code,
                               message: message_override || default_details&.fetch(:message, "Unknown error") # Use override, default, or generic
                             }
                             error_hash[:data] = data_override if data_override
                             JSON_RPC::Response.new(id: response_id, error: error_hash)
            when ->(ei) { ei } # Catch any other truthy value
                             raise ArgumentError, "The :error option for render :jsonrpc must be a Symbol or an Integer, got: #{error_input.inspect}"
            # # Original logic (removed): Treat payload_obj as the error hash
            # JSON_RPC::Response.new(id: response_id, error: payload_obj)
            else # Falsy (nil, false)
                             # Treat payload_obj as the result
                             JSON_RPC::Response.new(id: response_id, result: payload_obj)
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

# frozen_string_literal: true

# lib/jsonrpc_rails/railtie.rb
require_relative "middleware/validator"

module JSONRPC_Rails
  class Railtie < Rails::Railtie
    config.jsonrpc_rails = ActiveSupport::OrderedOptions.new
    config.jsonrpc_rails.validated_paths = []

    initializer "jsonrpc-rails.add_validator_middleware" do |app|
      app.middleware.use JSONRPC_Rails::Middleware::Validator
    end

    # -----------------------------------------------------------------------
    # Renderer
    # -----------------------------------------------------------------------
    initializer "jsonrpc-rails.add_renderers" do
      ActiveSupport.on_load(:action_controller) do
        ActionController::Renderers.add :jsonrpc do |obj, options|
          response_id = options[:id]
          error_opt = options[:error]

          begin
            payload =
              case obj
                # ─── Already JSON-RPC objects ───────────────────────────────
              when JSON_RPC::Response,
                JSON_RPC::Request,
                JSON_RPC::Notification
                obj.to_h

                # ─── Batch of objects ──────────────────────────────────────
              when Array
                unless obj.all? { |o| o.is_a?(JSON_RPC::Response) ||
                  o.is_a?(JSON_RPC::Request) ||
                  o.is_a?(JSON_RPC::Notification) }
                  raise ArgumentError, "Batch contains non-JSON-RPC objects"
                end
                obj.map(&:to_h)

                # ─── Legacy “result + :error” path ─────────────────────────
              else
                case error_opt
                when nil, false
                  JSON_RPC::Response.new(id: response_id,
                                         result: obj).to_h

                when Symbol
                  msg = obj.is_a?(Hash) ? obj[:message] : nil
                  dat = obj.is_a?(Hash) ? obj[:data] : nil
                  err = JSON_RPC::JsonRpcError.build(error_opt,
                                                     message: msg,
                                                     data: dat)
                  JSON_RPC::Response.new(id: response_id,
                                         error: err).to_h

                when Integer
                  defaults = JSON_RPC::JsonRpcError.find_by_code(error_opt)
                  msg = obj.is_a?(Hash) ? obj[:message] : nil
                  msg ||= defaults&.fetch(:message, "Unknown error")

                  dat = obj.is_a?(Hash) ? obj[:data] : nil
                  hash = { code: error_opt, message: msg }
                  hash[:data] = dat if dat
                  JSON_RPC::Response.new(id: response_id,
                                         error: hash).to_h

                when JSON_RPC::JsonRpcError
                  JSON_RPC::Response.new(id: response_id,
                                         error: error_opt.to_h).to_h

                when Hash
                  JSON_RPC::Response.new(id: response_id,
                                         error: error_opt).to_h

                else
                  raise ArgumentError,
                        ":error must be Symbol, Integer, Hash, or JSON_RPC::JsonRpcError " \
                          "(got #{error_opt.class})"
                end
              end

          rescue ArgumentError => e
            internal = JSON_RPC::JsonRpcError.new(:internal_error,
                                                  message: "Server error: #{e.message}")
            payload = { jsonrpc: "2.0", error: internal.to_h, id: response_id }

          rescue JSON_RPC::JsonRpcError => e
            payload = { jsonrpc: "2.0", error: e.to_h, id: response_id }
          end

          self.content_type ||= Mime[:json]
          self.response_body = payload.to_json
        end
      end
    end

    initializer "jsonrpc-rails.controller_helpers" do
      ActiveSupport.on_load(:action_controller) do
        require_relative "controller_helpers"
        include JSONRPC_Rails::ControllerHelpers
      end
    end
  end
end

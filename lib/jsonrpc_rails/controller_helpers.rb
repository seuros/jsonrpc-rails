# frozen_string_literal: true

module JSONRPC_Rails
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      # Returns a JSON_RPC::Request / Notification / Response
      # or an Array of them for batch calls.
      def jsonrpc_params
        request.env[:jsonrpc]
      end

      # Convenience boolean
      def jsonrpc_params_batch?
        jsonrpc_params.is_a?(Array)
      end
    end
  end
end

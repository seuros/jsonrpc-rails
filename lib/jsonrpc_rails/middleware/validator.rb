# frozen_string_literal: true

require "json"
require "active_support/json"
require "rack/media_type"
require "stringio"

module JSONRPC_Rails
  module Middleware
    # Rack middleware that **validates** incoming JSON-RPC 2.0 payloads
    # and injects fully-typed Ruby objects (Request / Notification /
    # Response) into `env[:jsonrpc]` for easy downstream use.
    #
    # Validation always runs on the raw Hash/Array first; objects are only
    # instantiated **after** the structure has been deemed valid, so malformed
    # IDs or empty batches no longer raise before we can return a proper
    # -32600 “Invalid Request”.
    class Validator
      CONTENT_TYPE = "application/json"
      ENV_PAYLOAD_KEY = :jsonrpc
      BATCH_POLICIES = %i[allow reject].freeze
      RESERVED_MEMBERS = %w[jsonrpc method params id result error].freeze

      # @param app [#call]
      # @param paths [Array<String, Regexp, Proc>] paths to validate
      # @param payload_validator [#valid?, #call, nil] optional protocol validator
      # @param batch_policy [Symbol] either :allow or :reject
      # @param require_json_content_type [Boolean] reject matching POST requests
      #   that do not use application/json instead of passing them downstream
      def initialize(app, paths = nil, payload_validator: nil, batch_policy: :allow,
                     require_json_content_type: false)
        unless BATCH_POLICIES.include?(batch_policy)
          raise ArgumentError, "batch_policy must be one of: #{BATCH_POLICIES.join(", ")}"
        end

        @app = app
        @paths = Array(paths || Rails.configuration.jsonrpc_rails.validated_paths)
        @payload_validator = payload_validator
        @batch_policy = batch_policy
        @require_json_content_type = require_json_content_type
      end

      # Rack entry point
      def call(env)
        return @app.call(env) unless validate_path?(env["PATH_INFO"])
        return @app.call(env) unless env["REQUEST_METHOD"] == "POST"

        unless json_content_type?(env["CONTENT_TYPE"])
          return @app.call(env) unless @require_json_content_type

          return jsonrpc_error_response(
            :server_error,
            status: 415,
            message: "Unsupported Media Type: Content-Type must be application/json"
          )
        end

        body = env["rack.input"].read
        # Replace consumed input with fresh StringIO for downstream middleware
        # This is Rack 3.0+ compatible and works with all input stream types
        env["rack.input"] = StringIO.new(body)

        begin
          raw_payload = ActiveSupport::JSON.decode(body)
        rescue ActiveSupport::JSON.parse_error
          return jsonrpc_error_response(:parse_error)
        end

        unless raw_payload.is_a?(Hash) || raw_payload.is_a?(Array)
          return jsonrpc_error_response(:invalid_request)
        end

        return invalid_request_response(raw_payload) unless valid_batch_policy?(raw_payload)
        return invalid_request_response(raw_payload) unless valid_payload_structure?(raw_payload)
        return invalid_request_response(raw_payload) unless valid_protocol_payload?(raw_payload)

        begin
          env[ENV_PAYLOAD_KEY] = convert_to_objects(raw_payload)
        rescue JSON_RPC::JsonRpcError, ArgumentError, TypeError
          return invalid_request_response(raw_payload)
        end

        @app.call(env)
      end

      private

      def validate_path?(path)
        return false if @paths.empty?

        @paths.any? do |matcher|
          case matcher
          when String then path == matcher
          when Regexp then matcher.match?(path)
          when Proc   then matcher.call(path)
          else             false
          end
        end
      end

      def json_content_type?(content_type)
        media_type = Rack::MediaType.type(content_type)&.strip
        media_type&.casecmp?(CONTENT_TYPE) || false
      end

      # -------------------- structure validation --------------------------------

      def valid_payload_structure?(payload)
        if payload.is_a?(Array)
          !payload.empty? && payload.all? { |message| valid_message_structure?(message) }
        else
          valid_message_structure?(payload)
        end
      end

      def valid_message_structure?(obj)
        return false unless obj.is_a?(Hash)
        return false unless obj["jsonrpc"] == "2.0"

        if obj.key?("method")
          valid_call_structure?(obj)
        elsif obj.key?("result") || obj.key?("error")
          valid_response_structure?(obj)
        else
          false
        end
      end

      def valid_call_structure?(obj)
        return false unless obj["method"].is_a?(String)
        return false unless valid_params?(obj)
        return false if obj.key?("id") && !valid_id?(obj["id"])

        no_conflicting_members?(obj, %w[jsonrpc method params id])
      end

      def valid_response_structure?(obj)
        return false unless obj.key?("id") && valid_id?(obj["id"])
        return false if obj.key?("result") == obj.key?("error")

        if obj.key?("result")
          no_conflicting_members?(obj, %w[jsonrpc id result])
        else
          valid_error_structure?(obj["error"]) &&
            no_conflicting_members?(obj, %w[jsonrpc id error])
        end
      end

      def valid_error_structure?(error)
        return false unless error.is_a?(Hash)
        return false unless error["code"].is_a?(Integer)
        return false unless error["message"].is_a?(String)

        true
      end

      def no_conflicting_members?(obj, allowed_members)
        (obj.keys & (RESERVED_MEMBERS - allowed_members)).empty?
      end

      def valid_params?(obj)
        !obj.key?("params") || obj["params"].is_a?(Array) || obj["params"].is_a?(Hash)
      end

      def valid_id?(id)
        id.is_a?(String) || id.is_a?(Numeric) || id.nil?
      end

      def valid_batch_policy?(payload)
        !payload.is_a?(Array) || @batch_policy == :allow
      end

      def valid_protocol_payload?(payload)
        return true unless @payload_validator

        if @payload_validator.respond_to?(:valid?)
          @payload_validator.valid?(payload)
        else
          @payload_validator.call(payload)
        end
      end

      # ------------------ conversion to typed objects ---------------------------

      def convert_to_objects(raw)
        case raw
        when Hash
          JSON_RPC::Parser.object_from_hash(raw)
        when Array
          raw.map { |h| JSON_RPC::Parser.object_from_hash(h) }
        else
          raw # should never get here after validation
        end
      end

      # ------------------ error response helper ---------------------------------

      # @param error_sym [Symbol]
      # @param status    [Integer]
      # @param id       [String, Numeric, nil]
      # @param message  [String, nil]
      # @return [Array] Rack triplet
      def jsonrpc_error_response(error_sym, status: 400, id: nil, message: nil)
        error_obj = JSON_RPC::JsonRpcError.build(error_sym, message: message)
        payload   = JSON_RPC::Response.new(id: id, error: error_obj).to_json

        [ status, { "content-type" => CONTENT_TYPE }, [ payload ] ]
      end

      def invalid_request_response(raw_payload)
        jsonrpc_error_response(:invalid_request, id: extract_id_from_raw_payload(raw_payload))
      end

      # Extract ID from raw payload if possible
      def extract_id_from_raw_payload(raw)
        return nil unless raw.is_a?(Hash)

        id = raw["id"]
        id if valid_id?(id)
      end
    end
  end
end

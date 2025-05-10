# frozen_string_literal: true

require "json"
require "active_support/json"

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
      CONTENT_TYPE     = "application/json"
      ENV_PAYLOAD_KEY  = :jsonrpc

      # @param app [#call]
      # @param paths [Array<String, Regexp, Proc>] paths to validate
      def initialize(app, paths = nil)
        @app   = app
        @paths = Array(paths || Rails.configuration.jsonrpc_rails.validated_paths)
      end

      # Rack entry point
      def call(env)
        return @app.call(env) unless validate_path?(env["PATH_INFO"])
        return @app.call(env) unless env["REQUEST_METHOD"] == "POST" &&
                                     env["CONTENT_TYPE"]&.start_with?(CONTENT_TYPE)

        body = env["rack.input"].read
        env["rack.input"].rewind

        raw_payload = parse_json(body)

        return jsonrpc_error_response(:invalid_request) unless raw_payload.is_a?(Hash) || raw_payload.is_a?(Array)

        validity, = if raw_payload.is_a?(Array)
                      validate_batch(raw_payload)
        else
                      validate_single(raw_payload)
        end
        return validity unless validity == :valid

        env[ENV_PAYLOAD_KEY] = convert_to_objects(raw_payload)

        @app.call(env)
      end

      private

      def parse_json(body)
        return nil if body.nil? || body.strip.empty?

        ActiveSupport::JSON.decode(body)
      rescue ActiveSupport::JSON.parse_error
        nil
      end

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

      # -------------------- structure validation --------------------------------

      def validate_single_structure(obj)
        return false unless obj.is_a?(Hash)
        return false unless obj["jsonrpc"] == "2.0"
        return false unless obj["method"].is_a?(String)

        return false if obj.key?("params") && !obj["params"].is_a?(Array) && !obj["params"].is_a?(Hash)

        return false if obj.key?("id") && ![ String, Integer, NilClass ].include?(obj["id"].class)

        allowed = %w[jsonrpc method params id]
        (obj.keys - allowed).empty?
      end

      def validate_single(obj)
        if validate_single_structure(obj)
          [ :valid, nil ]
        else
          [ jsonrpc_error_response(:invalid_request), nil ]
        end
      end

      def validate_batch(batch)
        return [ jsonrpc_error_response(:invalid_request), nil ] unless batch.is_a?(Array) && !batch.empty?

        invalid = batch.find { |el| !validate_single_structure(el) }
        invalid ? [ jsonrpc_error_response(:invalid_request), nil ] : [ :valid, nil ]
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
      # @return [Array] Rack triplet
      def jsonrpc_error_response(error_sym, status: 400)
        error_obj = JSON_RPC::JsonRpcError.build(error_sym)
        payload   = JSON_RPC::Response.new(id: nil, error: error_obj).to_json

        [ status, { "Content-Type" => CONTENT_TYPE }, [ payload ] ]
      end
    end
  end
end

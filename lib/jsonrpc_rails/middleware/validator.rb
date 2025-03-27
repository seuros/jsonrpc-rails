# frozen_string_literal: true

require "json"

module JSON_RPC_Rails
  module Middleware
    # Rack middleware to strictly validate incoming JSON-RPC 2.0 requests.
    # It checks for correct Content-Type, parses JSON, and validates the structure
    # of Hashes and non-empty Arrays according to JSON-RPC 2.0 spec.
    #
    # If validation passes, it stores the parsed payload in `request.env['jsonrpc.payload']`
    # and passes the request down the stack.
    #
    # If JSON parsing fails, or if the payload is a Hash/Array and fails JSON-RPC validation,
    # it immediately returns the appropriate JSON-RPC 2.0 error response.
    #
    # Other valid JSON payloads (e.g., strings, numbers, booleans, null) are passed through.
    class Validator
      CONTENT_TYPE = "application/json"
      ENV_PAYLOAD_KEY = "jsonrpc.payload"

      def initialize(app)
        @app = app
      end

      def call(env)
        request = Rack::Request.new(env)

        # Only process POST requests with the correct Content-Type
        unless request.post? && request.content_type&.start_with?(CONTENT_TYPE)
          return @app.call(env)
        end

        # Read and parse the request body
        body = request.body.read
        request.body.rewind # Rewind body for potential downstream middleware/apps
        payload = parse_json(body)

        # Handle JSON parsing errors
        return jsonrpc_error_response(:parse_error) unless payload

        # Only attempt JSON-RPC validation if payload is a Hash or Array
        unless payload.is_a?(Hash) || payload.is_a?(Array)
          # Pass through other valid JSON types (string, number, boolean, null)
          return @app.call(env)
        end

        # Payload is Hash or Array, proceed with JSON-RPC validation
        is_batch = payload.is_a?(Array)
        # validate_batch handles the empty array case internally now
        validation_result, _ = is_batch ? validate_batch(payload) : validate_single(payload)

        # If validation failed, return the generated error response
        return validation_result unless validation_result == :valid

        # Store the validated payload (original structure) in env for the controller
        env[ENV_PAYLOAD_KEY] = payload

        # Proceed to the next middleware/app
        @app.call(env)
      end

      private

      # Removed jsonrpc_payload? method

      # Parses the JSON body string. Returns parsed data or nil on failure.
      def parse_json(body)
        return nil if body.nil? || body.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      # Performs strict validation on a single object to ensure it conforms
      # to the JSON-RPC 2.0 structure (jsonrpc, method, params, id) and
      # has no extraneous keys.
      # Returns true if valid, false otherwise.
      def validate_single_structure(obj)
        # Must be a Hash
        return false unless obj.is_a?(Hash)

        # Must have 'jsonrpc' key with value '2.0'
        return false unless obj["jsonrpc"] == "2.0"

        # Must have 'method' key with a String value
        return false unless obj["method"].is_a?(String)

        # Optional 'params' must be an Array or Hash if present
        if obj.key?("params") && !obj["params"].is_a?(Array) && !obj["params"].is_a?(Hash)
          return false
        end

        # Optional 'id' must be a String, Number (Integer/Float), or Null if present
        if obj.key?("id") && ![ String, Integer, Float, NilClass ].include?(obj["id"].class)
          return false
        end

        # Check for extraneous keys
        allowed_keys = %w[jsonrpc method params id]
        return false unless (obj.keys - allowed_keys).empty?

        true # Structure is valid
      end


      # Validates a single JSON-RPC request object (must be a Hash).
      # Returns [:valid, nil] on success.
      # Returns [error_response_tuple, nil] on failure.
      def validate_single(obj)
        # Assumes obj is a Hash due to check in `call`
        if validate_single_structure(obj)
          [ :valid, nil ]
        else
          # Generate error response if structure is invalid (e.g., missing 'jsonrpc')
          [ jsonrpc_error_response(:invalid_request), nil ]
        end
      end

      # Validates a batch JSON-RPC request (must be an Array).
      # Returns [:valid, nil] if the batch structure is valid.
      # Returns [error_response_tuple, nil] if the batch is empty or any element is invalid.
      def validate_batch(batch)
        # Assumes batch is an Array due to check in `call`
        # Batch request must be a non-empty array according to spec
        unless batch.is_a?(Array) && !batch.empty?
          return [ jsonrpc_error_response(:invalid_request), nil ]
        end

        # Find first invalid element - stops processing as soon as it finds one
        invalid_element = batch.find { |element| !validate_single_structure(element) }

        # If an invalid element was found, return an error response immediately
        if invalid_element
          return [ jsonrpc_error_response(:invalid_request), nil ]
        end

        # All elements passed structural validation
        [ :valid, nil ]
      end

      # Generates a Rack response tuple for a given JSON-RPC error.
      # Middleware-level errors always have id: nil.
      # @param error_type [Symbol, JSON_RPC::JsonRpcError] The error symbol or object.
      # @param status [Integer] The HTTP status code.
      # @return [Array] Rack response tuple.
      def jsonrpc_error_response(error_type, status: 400)
        error_obj = if error_type.is_a?(JSON_RPC::JsonRpcError)
                      error_type
        else
                      JSON_RPC::JsonRpcError.new(error_type)
        end

        response_body = {
          jsonrpc: "2.0",
          error: error_obj.to_h,
          id: nil # Middleware errors have null id
        }.to_json

        [
          status,
          { "Content-Type" => CONTENT_TYPE },
          [ response_body ]
        ]
      end
    end
  end
end

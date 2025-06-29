# frozen_string_literal: true

module JSON_RPC
  # Represents a JSON-RPC response object.
  Response = Data.define(:id, :result, :error) do
    # Initializes a new Response.
    #
    # @param id [String, Numeric, nil] The request identifier. Must match the request ID.
    # @param result [Object, nil] The result data (if successful).
    # @param error [Hash, JSON_RPC::JsonRpcError, Symbol, nil] The error object/symbol (if failed).
    # @raise [ArgumentError] if both result and error are provided, or neither is provided for non-null id.
    def initialize(id:, **kwargs)
      # Check which parameters were actually provided
      has_result = kwargs.key?(:result)
      has_error = kwargs.key?(:error)

      result = kwargs[:result]
      error = kwargs[:error]

      validate_response(id, has_result, has_error, result, error)
      error_obj = process_error(error)

      super(id: id, result: result, error: error_obj)
    end

    def self.from_h(h)
      args = { id: h["id"] }
      args[:result] = h["result"] if h.key?("result")
      args[:error] = h["error"] if h.key?("error")
      new(**args)
    end

    # Returns a hash representation of the response, ready for JSON serialization.
    #
    # @return [Hash] The hash representation.
    def to_h
      hash = { "jsonrpc" => "2.0", id: id }
      if error
        hash[:error] = error # error is already a hash here
      else
        # Result must be included, even if null, for successful responses
        hash[:result] = result
      end
      hash
    end

    def as_json(*) = to_h

    private

    # Validates the response structure according to JSON-RPC 2.0 spec.
    #
    # @param id [Object] The request ID.
    # @param has_result [Boolean] Whether result was provided.
    # @param has_error [Boolean] Whether error was provided.
    # @param result [Object] The result data.
    # @param error_input [Object] The error data/object/symbol.
    # @raise [ArgumentError] for invalid combinations.
    def validate_response(id, has_result, has_error, result, error_input)
      # Cannot have both result and error
      if has_result && has_error
        raise ArgumentError, "Response cannot contain both 'result' and 'error'"
      end

      # If id is not null, either result or error MUST be present
      if !id.nil? && !has_result && !has_error
        raise ArgumentError, "Response with non-null ID must contain either 'result' or 'error'"
      end
    end

    # Processes the error input into a standard error hash.
    #
    # @param error_input [Hash, JSON_RPC::JsonRpcError, Symbol, nil] The error information.
    # @return [Hash, nil] The formatted error hash or nil.
    def process_error(error_input)
      case error_input
      when nil
        nil
      when JSON_RPC::JsonRpcError
        error_input.to_h
      when Hash
        # Assume it's already a valid JSON-RPC error object hash
        error_input
      when Symbol
        # Build from a standard error symbol (build returns a hash)
        JSON_RPC::JsonRpcError.build(error_input)
      else
        # Fallback to internal error if the format is unexpected
        JSON_RPC::JsonRpcError.build(:internal_error, message: "Invalid error format provided")
      end
    end
  end
end

# frozen_string_literal: true

module JSON_RPC
  # Custom exception class for JSON-RPC errors, based on the JSON-RPC 2.0 specification.
  class JsonRpcError < StandardError
    # Define the standard JSON-RPC 2.0 error codes
    ERROR_CODES = {
      parse_error: {
        code: -32_700,
        message: "Parse error"
      },
      invalid_request: {
        code: -32_600,
        message: "Invalid Request"
      },
      method_not_found: {
        code: -32_601,
        message: "Method not found"
      },
      invalid_params: {
        code: -32_602,
        message: "Invalid params"
      },
      internal_error: {
        code: -32_603,
        message: "Internal error"
      },
      # Implementation-defined server-errors -32000 to -32099
      server_error: {
        code: -32_000,
        message: "Server error"
      }
    }.freeze

    # @return [Integer] The error code.
    # @return [Object] The error data.
    attr_reader :code, :data

    # Retrieve error details by symbol.
    #
    # @param symbol [Symbol] The error symbol.
    # @raise [ArgumentError] if the error code is unknown.
    # @return [Hash] The error details.
    def self.[](symbol)
      ERROR_CODES[symbol] or raise ArgumentError, "Unknown error symbol: #{symbol}"
    end

    # Retrieve error details by code.
    #
    # @param code [Integer] The error code.
    # @return [Hash, nil] The error details hash if found, otherwise nil.
    def self.find_by_code(code)
      ERROR_CODES.values.find { |details| details[:code] == code }
    end

    # Build an error hash, allowing custom message or data to override defaults.
    #
    # @param symbol [Symbol] The error symbol.
    # @param message [String, nil] Optional custom message.
    # @param data [Object, nil] Optional custom data.
    # @return [Hash] The error hash.
    def self.build(symbol, message: nil, data: nil)
      error = self[symbol].dup
      error[:message] = message if message
      error[:data] = data if data
      error
    end

    # Initialize the error using a symbol key, with optional custom message and data.
    #
    # @param symbol [Symbol] The error symbol.
    # @param message [String, nil] Optional custom message.
    # @param data [Object, nil] Optional custom data.
    def initialize(symbol, message: nil, data: nil)
      error_details = self.class.build(symbol, message: message, data: data)
      @code = error_details[:code]
      @data = error_details[:data]
      super(error_details[:message])
    end

    # Returns a hash formatted for a JSON-RPC error response object (the value of the 'error' key).
    #
    # @return [Hash] The error hash.
    def to_h
      hash = { code: code, message: message }
      hash[:data] = data if data
      hash
    end

    # For ActiveSupport::JSON
    def as_json(*) = to_h
  end
end

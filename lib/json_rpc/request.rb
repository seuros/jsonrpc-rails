# frozen_string_literal: true

module JSON_RPC
  # Represents a JSON-RPC request object.
  Request = Data.define(:id, :method, :params) do
    # Initializes a new Request.
    #
    # @param id [String, Numeric, nil] The request identifier. Should be String or Numeric according to spec for requests needing a response. Can be nil.
    # @param method [String] The method name.
    # @param params [Hash, Array, nil] The parameters (optional). Structured value.
    # @raise [JSON_RPC::JsonRpcError] if the ID type is invalid.
    def initialize(id:, method:, params: nil)
      # Basic validation for ID type (String, Numeric, or null allowed by spec)
      validate_id_type(id)
      # Basic validation for method (e.g., non-empty string) could be added.
      super
    end

    def self.from_h(h)
      new(id: h["id"], method: h["method"], params: h["params"])
    end

    # Returns a hash representation of the request, ready for JSON serialization.
    #
    # @return [Hash] The hash representation.
    def to_h
      hash = {
        "jsonrpc" => "2.0",
        id: id, # Include id even if null, spec allows null id
        method: method
      }
      # Include params only if it's not nil
      hash[:params] = params unless params.nil?
      hash
    end

    def as_json(*) = to_h

    private

    # Validates the ID type according to JSON-RPC 2.0 spec.
    # Allows String, Numeric, or null.
    #
    # @param id [Object] The ID to validate.
    # @raise [JSON_RPC::JsonRpcError] if the ID type is invalid.
    def validate_id_type(id)
      return if id.is_a?(String) || id.is_a?(Numeric) || id.nil?

      # Using :invalid_request as the error type seems more appropriate for a malformed ID type.
      raise JSON_RPC::JsonRpcError.new(:invalid_request,
                                       message: "ID must be a string, number, or null")
    end
  end
end

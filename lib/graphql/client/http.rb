# frozen_string_literal: true
require "json"
require "net/http"
require "uri"

module GraphQL
  class Client
    # Public: Basic HTTP network adapter.
    #
    #   GraphQL::Client.new(
    #     execute: GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")
    #   )
    #
    # Assumes GraphQL endpoint follows the express-graphql endpoint conventions.
    #   https://github.com/graphql/express-graphql#http-usage
    #
    # Production applications should consider implementing their own network
    # adapter. This class exists for trivial stock usage and allows for minimal
    # request header configuration.
    class HTTP

      # Base exception for HTTP-related errors.
      class HTTPError < StandardError
        attr_reader :response
    
        # The initializer takes both a message and the response so that any caller can inspect the details.
        def initialize(message, response)
          @response = response
          super(message)
        end
      end
    
      # Exception for HTTP client errors (HTTP status codes 400-499).
      class ClientError < HTTPError; end
    
      # Exception for HTTP server errors (HTTP status codes 500-599).
      class ServerError < HTTPError; end
    
      # Checks the given Net::HTTPResponse.
      # If it represents a client or server error, raises a corresponding exception.
      def self.raise_for_http_error(response)
        # Convert the code to an integer for comparisons
        status = response.code.to_i
    
        # Return immediately if the response is a success (2xx)
        return if status >= 200 && status < 300
    
        # Construct a message that includes useful debugging info.
        error_message = "HTTP Error: #{response.code} #{response.message}. Response body: #{response.body}"
    
        # Determine whether it's a client or server error and raise the appropriate exception.
        case status
        when 400...500
          raise ClientError.new(error_message, response)
        when 500...600
          raise ServerError.new(error_message, response)
        else
          # For any other HTTP status that does not fall within our usual bounds,
          # you might choose to raise a generic HTTPError
          raise HTTPError.new(error_message, response)
        end
      end

      # Public: Create HTTP adapter instance for a single GraphQL endpoint.
      #
      #   GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/") do
      #     def headers(context)
      #       { "User-Agent": "My Client" }
      #     end
      #   end
      #
      # uri - String endpoint URI
      # block - Optional block to configure class
      def initialize(uri, &block)
        @uri = URI.parse(uri)
        singleton_class.class_eval(&block) if block_given?
      end

      # Public: Parsed endpoint URI
      #
      # Returns URI.
      attr_reader :uri

      # Public: Extension point for subclasses to set custom request headers.
      #
      # Returns Hash of String header names and values.
      def headers(_context)
        {}
      end

      # Public: full reponse from last request
      #
      # Returns Hash.
      attr_reader :last_response

      # Public: Make an HTTP request for GraphQL query.
      #
      # Implements Client's "execute" adapter interface.
      #
      # document - The Query GraphQL::Language::Nodes::Document
      # operation_name - The String operation definition name
      # variables - Hash of query variables
      # context - An arbitrary Hash of values which you can access
      #
      # Returns { "data" => ... , "errors" => ... } Hash.
      def execute(document:, operation_name: nil, variables: {}, context: {})
        request = Net::HTTP::Post.new(uri.request_uri)

        request.basic_auth(uri.user, uri.password) if uri.user || uri.password

        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        headers(context).each { |name, value| request[name] = value }

        body = {}
        body["query"] = document.to_query_string
        body["variables"] = variables if variables.any?
        body["operationName"] = operation_name if operation_name
        request.body = JSON.generate(body)

        response = connection.request(request)
        @last_response = response.to_hash
        case response
        when Net::HTTPOK, Net::HTTPBadRequest
          JSON.parse(response.body)
        else
          self.raise_for_http_error(response)
          { "errors" => [{ "message" => "#{response.code} #{response.message}" }] }
        end
      end

      # Public: Extension point for subclasses to customize the Net:HTTP client
      #
      # Returns a Net::HTTP object
      def connection
        Net::HTTP.new(uri.host, uri.port).tap do |client|
          client.use_ssl = uri.scheme == "https"
        end
      end
    end
  end
end

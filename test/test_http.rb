# frozen_string_literal: true
require "graphql"
require "graphql/client/http"
require "minitest/autorun"
require "net/http"

class TestHTTP < Minitest::Test
  SWAPI = GraphQL::Client::HTTP.new("https://mpjk0plp9.lp.gql.zone/graphql") do
    def headers(_context)
      { "User-Agent" => "GraphQL/1.0" }
    end
  end

  def setup
    @uri  = URI("https://example.com/graphql")
    @http = GraphQL::Client::HTTP.new(@uri)
  end

  def test_execute
    skip "TestHTTP disabled by default" unless __FILE__ == $PROGRAM_NAME

    document = GraphQL.parse(<<-'GRAPHQL')
      query getCharacter($id: ID!) {
        character(id: $id) {
          name
        }
      }
    GRAPHQL

    name = "getCharacter"
    variables = { "id" => "1001" }

    expected = {
      "data" => {
        "character" => {
          "name" => "Darth Vader"
        }
      }
    }
    actual = SWAPI.execute(document: document, operation_name: name, variables: variables)
    assert_equal(expected, actual)
  end

  def test_http_error_raises_exception
    response = Net::HTTPResponse.new("1.1", "404", "Not Found")
    response.instance_variable_set(:@body, "")

    error_response = @http.send(:handle_http_error, response)

    assert_equal(
      { "errors" => [{ "message" => "404 Not Found" }] },
      error_response
    )
  end

  def test_http_error_with_body_includes_body_in_error
    response = Net::HTTPResponse.new("1.1", "500", "Internal Server Error")
    response.instance_variable_set(:@body, "Something went wrong")

    error_response = @http.send(:handle_http_error, response)

    assert_equal(
      { "errors" => [{ "message" => "500 Internal Server Error: Something went wrong" }] },
      error_response
    )
  end

  def test_http_error_with_json_body_includes_json_in_error
    response = Net::HTTPResponse.new("1.1", "400", "Bad Request")
    response.instance_variable_set(:@body, '{"error": "Invalid query"}')

    error_response = @http.send(:handle_http_error, response)

    assert_equal(
      { "errors" => [{ "message" => "400 Bad Request: {\"error\": \"Invalid query\"}" }] },
      error_response
    )
  end
end

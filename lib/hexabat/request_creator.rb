require 'em-http-request'
require 'yajl'

require_relative 'page_range'

module Hexabat
  class RequestCreator
    MAX_PAGE_SIZE = 100

    def initialize(repository, &issue_retrieved)
      @repository = repository
      @callback = issue_retrieved
    end

    def for(params, &callback)
      build_request(params).tap do |request|
        request.callback &page_retrieved(callback)
        request.errback  &error_occurred
      end
    end

    def page_retrieved(page_callback = nil)
      ->(http) do
        parse_issues_from http.response do |issues|
          page_callback.call(PageRange.from(http.response_header), issues.count) unless page_callback.nil?
          notify_issue_retrieved issues
        end
      end
    end

    def error_occurred
      ->(http) do
        STDERR.puts "HEXABAT: Error retreiving page"
        STDERR.puts "HEXABAT: Status was #{http.response_header.status}"
        STDERR.puts "HEXABAT: Body was:\n===\n#{http.response}\n==="
      end
    end

    private

    def build_request(params)
      EM::HttpRequest.new(endpoint).get query: query_from(params)
    end

    def endpoint
      "https://api.github.com/repos/#{@repository}/issues"
    end

    def query_from(params)
      params.merge per_page: MAX_PAGE_SIZE
    end

    def parse_issues_from(json)
      yield Yajl::Parser.parse(json)
    end

    def notify_issue_retrieved(issues)
      issues.each do |issue|
        EM.next_tick { @callback.call issue }
      end
    end
  end

end

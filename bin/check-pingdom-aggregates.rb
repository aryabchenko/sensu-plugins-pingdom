#!/usr/bin/env ruby
#
# Check Pingdom aggregates (checks down)
# ===
#
# Alerts if too many websites are down in the Pingdom account.
# Default crit is 1.
#
# Usage
#   Authentication
#     Pingdom's API 3.1 requires just 1 parameter for authentication - the key
#
#   Thresholds of website checks down
#     --crit
#     --warn
#
#     --verbose: displays all check names that are down, as well as the count.
#
# Dependencies
#
# gem 'rest-client'
# gem 'json'
#
# Copyright 2013 Rock Solid Ops Inc. <hello@rocksolidops.com>
# Created by Mathieu Martin, 2013
# Modified by Anton Ryabchenko, 2019
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class CheckPingdomAggregates < Sensu::Plugin::Check::CLI
  option :application_key,
         short: '-k APP_KEY',
         long: '--application-key APP_KEY',
         required: true

  option :warn,
         short: '-w COUNT',
         default: 1,
         proc: proc(&:to_i),
         required: true
  option :crit,
         short: '-c COUNT',
         default: 1,
         proc: proc(&:to_i),
         required: true

  option :timeout,
         short: '-t SECS',
         default: 10
  option :verbose,
         short: '-v'

  def run
    down_count = down_checks.size

    if down_count >= config[:crit]
      critical "There are #{down_count} pingdom checks down#{details}"
    elsif down_count >= config[:warn]
      warning "There are #{down_count} pingdom checks down#{details}"
    else
      ok "There are less than #{config[:warn]} checks down"
    end
  end

  def details
    return nil unless config[:verbose]
    ":\n#{down_checks.map { |check| "#{check[:name]} is down" }.join("\n")}"
  end

  def down_checks
    # Cache the API call
    @down_checks ||= api_call[:checks].select { |check| 'down' == check[:status] }
  end

  def api_call
    resource = RestClient::Resource.new(
      'https://api.pingdom.com/api/3.1/checks',
      headers: { 'Authorization' => "Bearer #{config[:application_key]}" },
      timeout: config[:timeout]
    )
    JSON.parse(resource.get, symbolize_names: true)

  rescue RestClient::RequestTimeout
    warning 'Connection timeout'
  rescue SocketError
    warning 'Network unavailable'
  rescue Errno::ECONNREFUSED
    warning 'Connection refused'
  rescue RestClient::RequestFailed
    warning 'Request failed'
  rescue RestClient::RequestTimeout
    warning 'Connection timed out'
  rescue RestClient::Unauthorized
    warning 'Missing or incorrect API credentials'
  rescue JSON::ParserError
    warning 'API returned invalid JSON'
  end
end
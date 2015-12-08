require 'helper'

module EventMachine
  module DnsResolver
    MAX_TRIES = 1
    RETRY_INTERVAL = 1
  end
end

class TestEmDnsResolv < Test::Unit::TestCase
  should "fail if it cannot resolve and address" do
    port = EventMachine::DnsResolver::Port
    EventMachine::DnsResolver.stubs(:nameservers).returns([["1.2.3.4", port]])

    EM.run do
      df = EventMachine::DnsResolver.resolve('www.google.com')
      df.errback do |error|
        assert_equal "retries exceeded", error
        EM.stop
      end
    end
  end

  should "try all the nameservers before failing" do
    EventMachine::DnsResolver.stubs(:MAX_TRIES).returns(1)
    EventMachine::DnsResolver.stubs(:RETRY_INTERVAL).returns(1)
    port = EventMachine::DnsResolver::Port
    EventMachine::DnsResolver.stubs(:nameservers).returns([
      ["1.2.3.4", port], ["8.8.8.8", port] ])

    EM.run do
      df = EventMachine::DnsResolver.resolve('www.google.com')
      df.callback do |ip|
        ip = ip.first if ip.kind_of?(Array)
        assert_match /\d+\.\d+\.\d+\.\d+/, ip
        EM.stop
      end
      df.errback do |error|
        EM.stop
        fail error
      end
    end
  end
end

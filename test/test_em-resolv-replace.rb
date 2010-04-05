require 'helper'

class TestEmResolvReplace < Test::Unit::TestCase

  IPv4 = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/

  should "resolve address without eventmachine" do
    Resolv.any_instance.expects(:em_getaddress).times(0)

    assert_match IPv4, Resolv.getaddress('www.google.com')
  end
  
  should "resolve address with eventmachine" do
    Resolv.any_instance.expects(:orig_getaddress).times(0)

    EM.run do
      Fiber.new do
        assert_match IPv4, Resolv.getaddress('www.google.com')
        EM.stop
      end.resume
    end
  end

  should "resolve addresses without eventmachine" do
    Resolv.any_instance.expects(:em_getaddress).times(0)

    results = Resolv.getaddresses('www.google.com')
    assert_match IPv4, results.first
  end
  
  should "resolve addresses with eventmachine" do
    Resolv.any_instance.expects(:orig_getaddresses).times(0)

    EM.run do
      Fiber.new do
        results = Resolv.getaddresses('www.google.com')
        assert_match IPv4, results.first
        EM.stop
      end.resume
    end
  end

  should "resolve localhost with eventmachine" do
    Resolv.any_instance.expects(:orig_getaddresses).times(0)

    EM.run do
      Fiber.new do
        results = Resolv.getaddresses('localhost')
        assert (results.first =~ IPv4 || results.first =~ /::/), "Invalid IP #{results}"
        EM.stop
      end.resume
    end
  end

end

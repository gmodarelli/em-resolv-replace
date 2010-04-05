# Standard libc DNS resolution
require 'resolv'
# Override with pure Ruby DNS resolution
require 'resolv-replace'

require 'em-dns-resolver'
require 'fiber'

#
=begin
    require './em-resolv-replace'
    EM.run {
      Fiber.new do
        p Resolv.getaddresses('localhost')
        p Resolv.getaddress('localhost')
        EM.stop
      end.resume
    }
=end
# Now override the override with EM-aware functions
class Resolv
  
  alias :orig_getaddress :getaddress
  
  def getaddress(host)
    EM.reactor_running? ? em_getaddresses(host)[0] : orig_getaddress(host)
  end

  alias :orig_getaddresses :getaddresses

  def getaddresses(host)
    EM.reactor_running? ? em_getaddresses(host) : orig_getaddresses(host)
  end

  private

  def em_getaddresses(host)
    # Lookup in /etc/hosts
    x = []
    @hosts ||= Resolv::Hosts.new
    @hosts.each_address(host) {|addr| x << addr.to_s }
    return x unless x.empty?

    # Nothing, hit DNS
    fiber = Fiber.current
    df = EM::DnsResolver.resolve(host)
    df.callback do |a|
      fiber.resume(a)
    end
    df.errback do |*a|
      fiber.resume(ResolvError.new(a.inspect))
    end
    result = Fiber.yield
    if result.is_a?(StandardError)
      raise result
    end
    result
  end
end
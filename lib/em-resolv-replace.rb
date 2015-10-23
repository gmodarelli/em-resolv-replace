# Pure Ruby DNS resolution
require 'resolv'
# Override sockets to use Ruby DNS resolution
require 'resolv-replace'

require 'em-dns-resolver'
require 'fiber'

# Now override the override with EM-aware functions
class Resolv
  alias :orig_getaddress :getaddress

  def getaddress(host)
    event_machine? ? em_getaddresses(host)[0] : orig_getaddress(host)
  end

  alias :orig_getaddresses :getaddresses

  def getaddresses(host)
    event_machine? ? em_getaddresses(host) : orig_getaddresses(host)
  end

  alias :orig_getname :getname

  def getname(address)
    event_machine? ? em_getnames(address)[0] : orig_getname(address)
  end

  alias :orig_getnames :getnames

  def getnames(address)
    event_machine? ? em_getnames(address) : orig_getnames(address)
  end

  private

  def event_machine?
    EM.reactor_running? && EM.reactor_thread?
  end

  def em_getaddresses(host)
    em_request(host, :each_address, :resolve)
  end

  def em_getnames(address)
    em_request(address, :each_name, :reverse)
  end

  def em_request(value, hosts_method, resolv_method)
    # Lookup in /etc/hosts
    result = []
    @hosts ||= Resolv::Hosts.new
    @hosts.send(hosts_method, value) { |x| result << x.to_s }
    return result unless result.empty?

    # Nothing, hit DNS
    fiber = Fiber.current
    df = EM::DnsResolver.send(resolv_method, value)
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

require 'eventmachine'
require 'resolv'

module EventMachine
  module DnsResolver
    ##
    # Global interface
    ##

    Port = 53
    MAX_TRIES = 5
    RETRY_INTERVAL = 3

    def self.resolve(hostname)
      type = Resolv::DNS::Resource::IN::A
      if ::Resolv::AddressRegex =~ hostname
        # hostname contains an IP address, nothing to resolve
        Request.new(nil, hostname, type)
      else
        Request.new(socket, hostname, type)
      end
    end

    def self.reverse(address)
      case address
      when Resolv::IPv4::Regex
        ptr = Resolv::IPv4.create(address).to_name
      when Resolv::IPv6::Regex
        ptr = Resolv::IPv6.create(address).to_name
      else
        raise ArgumentError, "invalid address: #{address}"
      end
      Request.new(socket, ptr, Resolv::DNS::Resource::IN::PTR)
    end

    def self.socket
      if defined?(@socket) && @socket.connected?
        @socket
      else
        @socket = DnsSocket.open
      end
    end

    def self.nameservers
      return @nameservers if defined? @nameservers
      config_hash = ::Resolv::DNS::Config.default_config_hash

      @nameservers = if config_hash.include? :nameserver
                       config_hash[:nameserver].map do |ns|
                         [ ns, Port ]
                       end
                     elsif config_hash.include? :nameserver_port
                       config_hash[:nameserver_port]
                     else
                       [ '0.0.0.0', Port ]
                     end
    end

    ##
    # Socket stuff
    ##

    class RequestIdAlreadyUsed < RuntimeError
    end

    class DnsSocket < EM::Connection
      def self.open
        EM::open_datagram_socket('0.0.0.0', 0, self)
      end
      def post_init
        @requests = {}
        @connected = true
        EM.add_periodic_timer(0.1, &method(:tick))
      end
      # Periodically called each second to fire request retries
      def tick
        @requests.each do |id,req|
          req.tick
        end
      end
      def register_request(id, req)
        if @requests.has_key?(id)
          raise RequestIdAlreadyUsed
        else
          @requests[id] = req
        end
      end
      def send_packet(pkt, nameserver_port)
        send_datagram pkt, *nameserver_port
      end
      def nameserver_port= (ns_p)
        @nameserver_port = ns_p
      end
      def nameserver_port
        @nameserver_port ||= DnsResolver.nameserver_port
      end
      # Decodes the packet, looks for the request and passes the
      # response over to the requester
      def receive_data(data)
        msg = nil
        begin
          msg = Resolv::DNS::Message.decode data
        rescue
        else
          req = @requests[msg.id]
          if req
            @requests.delete(msg.id)
            req.receive_answer(msg)
          end
        end
      end
      def connected?; @connected; end
      def unbind
        @connected = false
      end
    end

    ##
    # Request
    ##

    class Request
      include Deferrable
      attr_accessor :retry_interval
      attr_accessor :max_tries
      def initialize(socket, value, type)
        @socket = socket
        @value = value
        @type = type
        @tries = 0
        @last_send = Time.at(0)
        @retry_interval = DnsResolver::RETRY_INTERVAL
        @max_tries = DnsResolver::MAX_TRIES
        @nameservers = DnsResolver.nameservers.dup
        @nameserver  = @nameservers.shift
        EM.next_tick { tick }
      end
      def tick
        # @value already contains the response
        if @socket.nil?
          succeed [ @value ]
          return
        end

        # Break early if nothing to do
        return if @last_send + @retry_interval > Time.now

        if @tries < @max_tries
          send(@nameserver)
        elsif @nameserver = @nameservers.shift
          @tries = 0
        else
          fail 'retries exceeded'
        end
      end
      # Called by DnsSocket#receive_data
      def receive_answer(msg)
        result = []
        msg.each_answer do |name,ttl,data|
          case data
          when Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA
            result << data.address.to_s
          when Resolv::DNS::Resource::IN::PTR
            result << data.name.to_s
          end
        end
        if result.empty?
          fail "rcode=#{msg.rcode}"
        else
          succeed result
        end
      end
      private
      def send(nameserver_port)
        @socket.send_packet(packet.encode, nameserver_port)
        @tries += 1
        @last_send = Time.now
      end
      def id
        begin
          @id = rand(65535)
          @socket.register_request(@id, self)
        rescue RequestIdAlreadyUsed
          retry
        end unless defined?(@id)

        @id
      end
      def packet
        msg = Resolv::DNS::Message.new
        msg.id = id
        msg.rd = 1
        msg.add_question @value, @type
        msg
      end
    end
  end
end

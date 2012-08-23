module LogjamZeromqAmqpBridge

  class Daemon
    def initialize(options = {})
      port = (options[:port] || 12345).to_i
      @context = ZMQ::Context.new(1)
      @socket = @context.socket(ZMQ::PULL)
      @socket.setsockopt(ZMQ::LINGER, 100)
      @socket.setsockopt(ZMQ::HWM, 100)
      @socket.bind("tcp://*:#{port}")
      @exchanges = {}
      trap("INT"){ shutdown }
      trap("TERM"){ shutdown }
    end

    def run
      #require "ruby-prof"
      #RubyProf.measure_mode = RubyProf::PROCESS_TIME
      #RubyProf.start
      socket = @socket
      @received = 0
      loop do
        exchange_name = socket.recv
        next unless socket.getsockopt(ZMQ::RCVMORE)
        routing_key = socket.recv
        next unless socket.getsockopt(ZMQ::RCVMORE)
        data = socket.recv
        # puts routing_key
        @received += 1
        # shutdown if @received >=10000
        publish(exchange_name, routing_key, data)
      end
    end

    def shutdown
      puts "shutting down"
      puts "after #{@received} messages"
      #result = RubyProf.stop
      #printer = RubyProf::MultiPrinter.new(result)
      #printer.print(:path => ".",
      #              :profile => "mumu",
      #              :min_percent => 1, :threshold => 1)
      reset
      @socket.close
      @context.close
      exit!
    end

    def publish(exchange_name, key, data)
      return if paused?
      exchange(exchange_name).publish(data, :key => key, :persistent => false)
    rescue Exception => exception
      pause(exception)
    end

    def reset(exception=nil)
      return unless @bunny
      begin
        if exception
          @bunny.__send__(:close_socket)
        else
          @bunny.stop
        end
      rescue Exception
        # if bunny throws an exception here, its not usable anymore anyway
      ensure
        @exchanges.clear
        @bunny = nil
      end
    end

    def pause(exception)
      @paused = Time.now
      reset(exception)
      $stderr.puts "Could not log to AMQP exchange (#{exception.message}: #{exception.backtrace.join("\n")})"
    end

    RETRY_AFTER = 5

    def paused?
      @paused && @paused > Time.now-RETRY_AFTER
    end

    #TODO: verify socket_timout for ruby 1.9
    def bunny
      @bunny ||= Bunny.new(:host => "localhost", :socket_timeout => 0.1)
    end

    def exchange(name)
      @exchanges[name] ||=
        begin
          bunny.start unless bunny.connected?
          bunny.exchange(name, :durable => true, :auto_delete => false, :type => :topic)
        end
    end

  end

end

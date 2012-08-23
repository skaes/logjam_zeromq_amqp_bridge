require "em-zeromq-mri"
require "amqp"

module LogjamZeromqAmqpBridge

  class Daemon
    def initialize(options = {})
      @port = (options[:port] || 12345).to_i
      @received = 0
      @exchanges = {}
    end

    def setup_zmq
      @context = EM::ZeroMQ::Context.new(1)
      @socket = @context.socket(ZMQ::PULL)
      @socket.setsockopt(ZMQ::LINGER, 100)
      @socket.setsockopt(ZMQ::HWM, 100)
      @context.bind(@socket, "tcp://*:#{@port}", MessageHandler.new(self))
    end

    class MessageHandler
      def initialize(daemon)
        @daemon = daemon
      end
      def on_readable(socket, messages)
        # p messages
        @daemon.publish(*messages)
      rescue Exception
        p messages
      end
    end

    def setup_amqp
      @connection = AMQP.connect(:host => '127.0.0.1')
      @channel    = AMQP::Channel.new(@connection)
#       @channel.on_error do |ch, channel_close|
#         puts "Channel-level error: #{channel_close.reply_text}, shutting down..."
#         @connection.close { EM.stop }
#       end
    end

    def run
      EM.run do
        trap("INT"){ shutdown }
        trap("TERM"){ shutdown }
        setup_amqp
        setup_zmq
        start_profiling if ENV['RUBY_PROF']
        # GC.enable_stats
        # GC.enable_trace
      end
    end

    def shutdown
      puts "shutting down"
      puts "after #{@received} messages"
      stop_profiling if defined?(RubyProf)
      # @socket.close
      # @context.close
      # GC.dump_file_and_line_info("heap.dump", true) if GC.respond_to?(:dump_file_and_line_info)
      EM.stop
    end

    def start_profiling
      require "ruby-prof"
      RubyProf.measure_mode = RubyProf::WALL_TIME
      RubyProf.start
    end

    def stop_profiling
      result = RubyProf.stop
      printer = RubyProf::MultiPrinter.new(result)
      printer.print(:path => ".", :profile => "mumu", :min_percent => 1, :threshold => 1)
      system("open #{printer.stack_profile}") if RUBY_PLATFORM =~ /darwin/
    end

    def publish(exchange_name, key, data)
      @received += 1
      exchange(exchange_name).publish(data, :key => key, :persistent => false)
    rescue Exception => exception
      $stderr.puts exception
    end

    def exchange(name)
      @exchanges[name] ||=
        @channel.topic(name, :durable => true, :auto_delete => true).tap{sleep 0.05}
    end

  end

end

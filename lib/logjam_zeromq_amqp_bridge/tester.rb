require "benchmark"
require "zmq"

module LogjamZeromqAmqpBridge
  class Tester
    def initialize(message_count=10000)
      @message_count = message_count.to_i
      @context = ZMQ::Context.new(1)
      @socket = @context.socket(ZMQ::PUSH)
      @socket.setsockopt(ZMQ::LINGER, 100)
      @socket.setsockopt(ZMQ::HWM, 100)
      @socket.connect("tcp://localhost:12345")
      # @socket.connect("tcp://localhost:12346")
      @published = 0
      @lost = 0
      trap("INT"){ shutdown }
      trap("TERM"){ shutdown }
    end

    DATA = "a" * 4000
    EXCHANGES = %w(zmq-bridge-tester-1 zmq-bridge-tester-2)

    def run
      socket = @socket
      duration = Benchmark.realtime do
        @message_count.times do
          sent = socket.send(EXCHANGES[@published % 2], ZMQ::SNDMORE|ZMQ::NOBLOCK)
          sent = false unless socket.send("logjam.zmq.test.#{@published}", ZMQ::SNDMORE|ZMQ::NOBLOCK)
          sent = false unless socket.send(DATA, ZMQ::NOBLOCK)
          @published += 1
          @lost += 1 unless sent
          # puts @published
          sleep 0.00002
        end
      end
      printf "runtime %.3fs, msgs/sec=%.3f", duration, (@published-@lost)/duration
      shutdown
    end

    def shutdown
      puts
      printf "pubs %10d\n", @published
      printf "lost %10d\n", @lost
      @socket.close
      @context.close
      exit!
    end
  end
end

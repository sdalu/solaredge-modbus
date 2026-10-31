# frozen_string_literal: true

# A Modbus TCP device on 127.0.0.1 for transport tests, never the
# network: each connection is handed to the next handler in turn.
module LoopbackDevice
    private

    # One handler per connection, in order, each on its own thread so
    # that one still sleeping never holds up the next connection; each
    # gets the connection and the request bytes. The transport times
    # out after 0.2 s.
    def device(*handlers)
        with_server do |server, port|
            thread = Thread.new { serve(server, handlers) }
            yield SolarEdge::Modbus::Transport.new("127.0.0.1", port,
                                                   timeout: 0.2)
            thread.join(2)&.value&.each { it.join(2) }
        end
    end

    def serve(server, handlers)
        handlers.map do |handler|
            conn = server.accept
            Thread.new { handle(conn, handler) }
        end
    end

    def handle(conn, handler)
        handler.call(conn, conn.readpartial(1024))
    rescue IOError, SystemCallError
        nil
    ensure
        conn&.close
    end

    def with_server
        server = TCPServer.new("127.0.0.1", 0)
        yield(server, server.addr[1])
    ensure
        server.close
    end

    # A handler answering each request with `pdu`.
    def answer(pdu, **)
        ->(conn, request) { conn.write(reply(request, pdu.b, **)) }
    end

    # The MBAP frame answering `request`: its tid and unit unless told.
    def reply(request, pdu, tid: request.unpack1("n"))
        [tid, 0, pdu.bytesize + 1, request.getbyte(6)].pack("nnnC") + pdu
    end

    def read_pdu(registers)
        [3, registers.size * 2, *registers].pack("CCn*")
    end
end

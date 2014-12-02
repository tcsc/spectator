defmodule Spectator.Multicast do
    use GenServer
    require Record

    Record.defrecord :state, tx: nil, rx: nil

    def start_link(addr, port, ttl, timeout) do
        GenServer.start_link(__MODULE__, [addr, port, ttl, timeout], name: __MODULE__)
    end

    def discover do
        GenServer.call(__MODULE__, :look_around)
    end

    def init([addr, port, ttl, timeout]) do
        socket_options = [
            active: true,
            ip: addr,
            add_membership: {addr, {0,0,0,0}},
            multicast_loop: true,
            reuseaddr: true,
            mode: :binary
        ]

        {:ok, rx} = :gen_udp.open(port, socket_options)
        {:ok, state(tx: mk_send_socket(ttl), rx: rx)}
    end

    def handle_call(:look_around, _from, _state) do
        IO.puts "handle_call(:look_around, #{inspect _from}, #{inspect _state}])"
        {:ok, _state}
    end

    def terminate(_state) do
        IO.puts "terminate(#{inspect _state}])"
    end

    def mk_send_socket(ttl) do
        opts = [ip: {0,0,0,0}, multicast_ttl: ttl, multicast_loop: true]
        {:ok, s} = :gen_udp.open(0, opts)
        s
    end

    @spec format_packet(String, String, integer) :: binary
    @doc """
    Formats a discovery packet into a binary, ready for sending.
    """
    def format_packet(nodestring, cookie, salt) do
        protocol_version = 0
        len = byte_size nodestring
        hash = hash_cookie(salt, cookie)
        << "spectator",
           protocol_version :: size(8),
           salt :: big-unsigned-integer-size(32),
           hash :: binary, 
           len  :: big-unsigned-integer-size(16),
           nodestring :: binary >>
    end

    @spec parse_packet(binary) :: {:ok, {integer, binary, String}} | :error
    @doc """
    Attempts to parse a binary as a discovery packet. 
    """
    def parse_packet(pkt) do
        try do 
            <<"spectator", 
              0 :: size(8),
              salt :: big-unsigned-integer-size(32),
              hash :: binary-size(16),
              len :: big-unsigned-integer-size(16),
              nodestring :: binary>> = pkt
            {:ok, {salt, hash, nodestring}}
        rescue MatchError -> :error
        end
    end

    @spec check_cookie(String, integer, binary) :: boolean
    @doc """
    Checks to see if a cookie hash matches a packet supplied hash.
    """
    def check_cookie(cookie, salt, hash) do
        hash == hash_cookie(salt, cookie)
    end

    defp hash_cookie(salt, cookie) do
        :crypto.hash(:md5, <<cookie :: binary, salt :: unsigned-big-integer-size(32)>>)
    end
end
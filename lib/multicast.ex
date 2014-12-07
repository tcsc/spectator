defmodule Spectator.Multicast do
    use GenServer
    require Record
    require Logger

    Record.defrecord :state, tx: nil, 
                             rx: nil, 
                             addr: {0, 0, 0, 0}, 
                             port: 0

    def start_link(addr, port, ttl, timeout) do
        {:ok, pid} = GenServer.start_link(__MODULE__, [addr, port, ttl, timeout], name: __MODULE__)
        announce
        {:ok, pid}
    end

    @spec announce() :: nil
    def announce do
        GenServer.call(__MODULE__, :look_around)
    end

    @spec port() :: integer
    @doc """
    Fetches the port that the defaut spectator instance is listening and 
    broadcasting on.
    """
    def port, do: port(__MODULE__)

    @spec port(pid | atom) :: term
    @doc """
    Fetches the port number of a given multicast listener.
    """
    def port(pid) do 
        GenServer.call(pid, :get_port)
    end 

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    def init([addr, port, ttl, timeout]) do
        socket_options = [
            active: true,
            ip: addr,
            add_membership: {addr, {0,0,0,0}},
            reuseaddr: true,
            mode: :binary
        ]

        {:ok, rx} = :gen_udp.open(port, socket_options)
        {:ok, state(tx: mk_send_socket(ttl), rx: rx, port: port, addr: addr)}
    end

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    def handle_call(:look_around, _from, s) do
        salt = :crypto.rand_uniform 0, 0x7FFFFFFF
        cookie = to_string :erlang.get_cookie
        node = to_string :erlang.node
        pkt = format_packet node, cookie, salt
        :ok = :gen_udp.send state(s, :tx), state(s, :addr), state(s, :port), pkt
        {:reply, nil, s}
    end

    def handle_call(:get_port, _from, s) do
        {:reply, state(s, :port), s}
    end

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    # Handles a UDP packet from the reception socket.
    def handle_info({:udp, _sock, _src, _port, pkt}, s) do 
        handle_packet(pkt)
        {:noreply, s}
    end

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    def terminate(s) do
        :gen_udp.close state(s, :tx)
        :gen_udp.close state(s, :rx)
        :ok
    end

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    defp mk_send_socket(ttl) do
        opts = [ip: {0,0,0,0}, multicast_ttl: ttl, multicast_loop: true]
        {:ok, s} = :gen_udp.open(0, opts)
        s
    end

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    defp handle_packet(pkt) do
        case parse_packet pkt do
            {:ok, {salt, hash, other_node}} ->
                my_cookie = to_string :erlang.get_cookie
                if check_cookie my_cookie, salt, hash do
                    Logger.info "Spectator: Welcome, #{other_node}"
                    :net_adm.ping (String.to_atom other_node)
                end
            :error -> nil
        end
    end

    ## ------------------------------------------------------------------------
    ## 
    ## ------------------------------------------------------------------------

    @spec format_packet(String.t, String.t, integer) :: << _ :: _ * 8>>
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

    @spec parse_packet(binary) :: {:ok, {integer, <<_ :: 128>>, String.t}} | :error
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

    @spec check_cookie(String.t, integer, <<_ :: 128>>) :: boolean
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
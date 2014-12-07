defmodule MulticastTest do
  use ExUnit.Case
  alias Spectator.Multicast

  setup context do
    on_exit fn ->
      Application.St
  end

  test "packets are formatted as expected" do
    pkt = Multicast.format_packet("name@node", "cookie", 12345)
    exp = <<"spectator", 
            0 :: size(8), # protocol version 
            12345 :: big-unsigned-integer-size(32),
            <<168, 89, 83, 51, 202, 162, 197, 43, 88, 20, 94, 155, 246, 108, 43, 168>> :: binary,
            9 :: big-unsigned-integer-size(16),
            "name@node">>
    assert pkt == exp
  end

  test "valid packets can be parsed" do
    pkt = Multicast.format_packet("name@node", "somecookie", 54321)
    exp = {:ok, {54321, <<131, 205, 173, 157, 40, 209, 205, 211, 103, 223, 83, 229, 43, 169, 79, 94>>, "name@node"}}
    assert Multicast.parse_packet(pkt) == exp
  end

  test "parsing an invalid packet returns an error" do
    assert Multicast.parse_packet(<<"narf!">>) == :error
  end

  test "checking a valid hash returns true" do
    pkt = Multicast.format_packet("name@node", "somecookie", 54321)
    {:ok, {salt, hash, _}} = Multicast.parse_packet(pkt)
    assert Multicast.check_cookie "somecookie", salt, hash
  end

  test "checking an invalid valid hash returns false" do
    pkt = Multicast.format_packet("name@node", "somecookie", 54321)
    {:ok, {salt, hash, _}} = Multicast.parse_packet(pkt)
    assert not Multicast.check_cookie "someothercookie", salt, hash
  end

  test "invoking discover sends a valid packet" do
    {:ok, pid} = Multicast.start_link {0,0,0,0}, 4475, 5, 300
    try do
      {:ok, rx} = :gen_udp.open port, [
        active: true,
        ip: {0,0,0,0},
        add_membership: {addr, {0,0,0,0}},
        multicast_loop: true,
        reuseaddr: true,
        mode: :binary
      ]
      Multicast.discover pid

      receive do
        {:udp, _, 4475, _, <<"spactator", _ :: binary>>} -> assert true
      after
        1000 -> assert false
      end
    after
      Multicast.stop()
    end
  end
end
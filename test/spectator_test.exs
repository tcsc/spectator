defmodule SpectatorTest do
  use ExUnit.Case
  alias Spectator.Multicast

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
end

defmodule IPATest do
  use ExUnit.Case
  # doctest IPA

  ExUnit.configure exclude: :pending, trace: true

  test "validity of dotted decimal addresses" do
    assert IPA.valid_address?("192.168.0.1")
    refute IPA.valid_address?("192.168.256.256")
    refute IPA.valid_address?("192.168.0")
    refute IPA.valid_address?("192.168")
    refute IPA.valid_address?("192.168.0.1.1")
    refute IPA.valid_address?("192.168.0.1.1.")
    refute IPA.valid_address?("192.168.0.1.")
  end

  test "valid binary address" do
    assert IPA.valid_address?("0b11000000101010000000000000000001")
  end

  test "valid bits address" do
    assert IPA.valid_address?("11000000.10101000.00000000.00000001")
  end

  test "valid hex address" do
    assert IPA.valid_address?("0xC0A80001")
  end

  test "valid octets address" do
    assert IPA.valid_address?({192, 168, 0, 1})
  end

  @tag :pending
  test "valid subnet mask" do
    assert IPA.valid_mask?(24)
    assert IPA.valid_mask?("255.255.255.0")
    assert IPA.valid_mask?("11111111.11111111.11111111.00000000")
  end

  @tag :pending
  test "invalid subnet masks" do
    refute IPA.valid_mask?("11111111.00000000.11111111.00000000")
    refute IPA.valid_mask?("10101000.10101000.10101000.10101000")
    refute IPA.valid_mask?("00000000.00000000.00000000.00000000")
    refute IPA.valid_mask?("192.168.0.1")
    refute IPA.valid_mask?("256.256.0.0")
    refute IPA.valid_mask?(0)
    refute IPA.valid_mask?(33)
  end

  @tag :pending
  test "dot decimal address to hex" do
    assert IPA.to_hex("192.168.0.1") == "0xC0A80001"
  end

  @tag :pending
  test "invalid dot decimal address to hex raises error" do
    assert_raise IPError, "Invalid IP Address", fn ->
      IPA.to_hex("192.168.256.256")
    end
  end

  @tag :pending
  test "dot decimal address to bits" do
    assert IPA.to_bits("192.168.0.1") == "11000000.10101000.00000000.00000001"
  end

  @tag :pending
  test "invalid dot decimal address to bits raises error" do
    assert_raise IPError, "Invalid IP Address", fn ->
      IPA.to_bits("192.168.256.256")
    end
  end

  test "addresses to binary" do
    assert IPA.to_binary("192.168.0.1") == "0b11000000101010000000000000000001"
    assert IPA.to_binary({192, 168, 0, 1}) == "0b11000000101010000000000000000001"
    assert IPA.to_binary("0xC0A80001") == "0b11000000101010000000000000000001"
    assert IPA.to_binary("11000000.10101000.00000000.00000001") == "0b11000000101010000000000000000001"
  end

  @tag :pending
  test "invalid dot decimal address to binary raises error" do
    assert_raise IPError, "Invalid IP Address", fn ->
      IPA.to_binary("192.168.256.256")
    end
  end

  @tag :pending
  test "slash notation subnet mask to binary" do
    assert IPA.to_binary(24) == "0b11111111111111111111111100000000"
  end

  @tag :pending
  test "invalid slash notation subnet mask raises error" do
    assert_raise SubnetError, "Invalid Subnet Mask", fn ->
      IPA.to_binary(-1)
    end
    assert_raise SubnetError, "Invalid Subnet Mask", fn ->
      IPA.to_binary(33)
    end
  end

  @tag :pending
  test "dot decimal address to octets" do
    assert IPA.to_octets("192.168.0.1") == {192, 168, 0, 1}
  end

  @tag :pending
  test "invalid dot decimal address to octets raises error" do
    assert_raise IPError, "Invalid IP Address", fn ->
      IPA.to_octets("192.168.256.256")
    end
  end

  test "public address is not reserved" do
    refute IPA.reserved?("8.8.8.8")
  end

  test "private addresses are reserved" do
    assert IPA.reserved?("0.0.0.0")
    assert IPA.reserved?("10.0.0.0")
    assert IPA.reserved?("100.64.0.0")
    assert IPA.reserved?("127.0.0.0")
    assert IPA.reserved?("169.254.0.0")
    assert IPA.reserved?("172.16.0.0")
    assert IPA.reserved?("192.0.0.0")
    assert IPA.reserved?("192.0.2.0")
    assert IPA.reserved?("192.88.99.0")
    assert IPA.reserved?("192.168.0.0")
    assert IPA.reserved?("198.18.0.0")
    assert IPA.reserved?("198.51.100.0")
    assert IPA.reserved?("203.0.113.0")
    assert IPA.reserved?("224.0.0.0")
    assert IPA.reserved?("240.0.0.0")
    assert IPA.reserved?("255.255.255.255")
  end

  test "IP Address blocks" do
    assert IPA.block("8.8.8.8") == :public
    assert IPA.block("0.0.0.0") == :this_network
    assert IPA.block("10.0.0.0") == :rfc1918
    assert IPA.block("100.64.0.0") == :rfc6598
    assert IPA.block("127.0.0.0") == :loopback
    assert IPA.block("169.254.0.0") == :link_local
    assert IPA.block("172.16.0.0") == :rfc1918
    assert IPA.block("192.0.0.0") == :rfc5736
    assert IPA.block("192.0.2.0") == :rfc5737
    assert IPA.block("192.88.99.0") == :rfc3068
    assert IPA.block("192.168.0.0") == :rfc1918
    assert IPA.block("198.18.0.0") == :rfc2544
    assert IPA.block("198.51.100.0") == :rfc5737
    assert IPA.block("203.0.113.0") == :rfc5737
    assert IPA.block("224.0.0.0") == :multicast
    assert IPA.block("240.0.0.0") == :future
    assert IPA.block("255.255.255.255") == :limited_broadcast
  end
end

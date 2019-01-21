defmodule IPA do
  @moduledoc """
  Functions for working with IP addresses.

  Currently only compatible with IPv4 addresses.
  """

  @type ip :: addr | mask
  @type addr :: String.t
  @type mask :: String.t | non_neg_integer

  @mask_regex ~r/^((1|0){1,8}\.){3}(1|0){1,8}$/
  @mask_bits [[], [128], [192], [224], [240], [248], [252], [254], [255]]

  @doc """
  Checks if the given IP address is valid.

  Does not currently take into consideration
  the fact that `127.1` can be considered a valid IP address
  that translates to `127.0.0.1`.

  ## Examples

      iex> IPA.valid_address?("192.168.0.1")
      true
      iex> IPA.valid_address?("8.8.8.8")
      true
      iex> IPA.valid_address?("192.168.0.256")
      false
      iex> IPA.valid_address?("192.168.0")
      false
      iex> IPA.valid_address?("192.168.0.1.1")
      false
      iex> IPA.valid_address?("11000000.10101000.00000000.00000001")
      true
      iex> IPA.valid_address?("0xC0A80001")
      true
      iex> IPA.valid_address?("0b11000000101010000000000000000001")
      true
      iex> IPA.valid_address?({192, 168, 0, 1})
      true
  """
  @spec valid_address?(addr) :: boolean
  def valid_address?(addr) do
    if pre_transformation_validations(addr) do
      addr |> to_octet_list |> validate_octet_list
    else
      false
    end
  end

  @doc """
  Checks if the given subnet mask is valid.

  ## Examples

      iex> IPA.valid_mask?(24)
      true
      iex> IPA.valid_mask?(33)
      false
      iex> IPA.valid_mask?("255.255.255.0")
      true
      iex> IPA.valid_mask?("192.168.0.1")
      false
      iex> IPA.valid_mask?("11111111.11111111.11111111.00000000")
      true
      iex> IPA.valid_mask?("10101000.10101000.00000000.00000000")
      false
      iex> IPA.valid_mask?("0xFFFFFF00")
      true
      iex> IPA.valid_mask?("0b11111111111111111111111100000000")
      true
      iex> IPA.valid_mask?({255, 255, 255, 0})
      true
  """
  @spec valid_mask?(mask) :: boolean
  def valid_mask?(mask) when is_integer(mask) do
    case mask do
      mask when mask > 0 and mask < 33 -> true
      _ -> false
    end
  end
  def valid_mask?(mask) when is_tuple(mask) do
    mask |> mask_to_bits |> valid_mask?
  end
  def valid_mask?(mask) do
    cond do
      Regex.match?(@mask_regex, mask) ->
        [h|t] = mask
          |> String.replace(".", "")
          |> String.to_charlist
        binary_validation(h, t, [])
      valid_address?(mask) ->
        mask |> mask_to_bits |> valid_mask?
      true -> false
    end
  end

  @doc """
  Converts CIDR, binary, hexadecimal, dotted binary and tuple
  notation IP address/subnet mask to dotted decimal.

  ## Example

      iex> IPA.to_dotted_dec(24)
      "255.255.255.0"
      iex> IPA.to_dotted_dec({192, 168, 0, 1})
      "192.168.0.1"
      iex> IPA.to_dotted_dec("0b11000000101010000000000000000001")
      "192.168.0.1"
      iex> IPA.to_dotted_dec("0xC0A80001")
      "192.168.0.1"
      iex> IPA.to_dotted_dec("11000000.10101000.00000000.00000001")
      "192.168.0.1"
      iex> IPA.to_dotted_dec(33)
      ** (SubnetError) Invalid Subnet Mask
  """
  @spec to_dotted_dec(ip) :: String.t
  def to_dotted_dec(ip)

  def to_dotted_dec(mask) when is_integer(mask), do: do_to_dotted_dec(mask, SubnetError)
  def to_dotted_dec(addr), do: do_to_dotted_dec(addr, IPError)

  defp do_to_dotted_dec(ip, error) do
    ip_list = if pre_transformation_validations(ip) do
      ip |> to_octet_list
    else
      raise error
    end
    if validate_octet_list(ip_list) do
      Enum.join(ip_list, ".")
    else
      raise error
    end
  end

  @doc """
  Converts CIDR, binary, hexadecimal, dotted binary and tuple
  notation IP address/subnet mask to a `0b` prefixed binary number.

  ## Example

      iex> IPA.to_binary("192.168.0.1")
      "0b11000000101010000000000000000001"
      iex> IPA.to_binary("0xC0A80001")
      "0b11000000101010000000000000000001"
      iex> IPA.to_binary("11000000.10101000.00000000.00000001")
      "0b11000000101010000000000000000001"
      iex> IPA.to_binary({192, 168, 0, 1})
      "0b11000000101010000000000000000001"
      iex> IPA.to_binary("255.255.255.0")
      "0b11111111111111111111111100000000"
      iex> IPA.to_binary(24)
      "0b11111111111111111111111100000000"
      iex> IPA.to_binary("255.255.256.0")
      ** (IPError) Invalid IP Address
  """
  @spec to_binary(ip) :: String.t
  def to_binary(ip)

  def to_binary(mask) when is_integer(mask), do: do_to_binary(mask, SubnetError)
  def to_binary(addr), do: do_to_binary(addr, IPError)

  defp do_to_binary(ip, error) do
    ip_list = if pre_transformation_validations(ip) do
      ip |> to_octet_list
    else
      raise error
    end
    if validate_octet_list(ip_list) do
      transform_addr(ip_list, 2, 8, "", "0b")
    else
      raise error
    end
  end

  @doc """
  Converts CIDR, binary, hexadecimal, dotted binary and tuple
  notation IP address/subnet mask to binary bits.

  ## Example

      iex> IPA.to_bits("192.168.0.1")
      "11000000.10101000.00000000.00000001"
      iex> IPA.to_bits("0xC0A80001")
      "11000000.10101000.00000000.00000001"
      iex> IPA.to_bits({192, 168, 0, 1})
      "11000000.10101000.00000000.00000001"
      iex> IPA.to_bits("0b11000000101010000000000000000001")
      "11000000.10101000.00000000.00000001"
      iex> IPA.to_bits("255.255.255.0")
      "11111111.11111111.11111111.00000000"
      iex> IPA.to_bits(24)
      "11111111.11111111.11111111.00000000"
      iex> IPA.to_bits("192.168.0.256")
      ** (IPError) Invalid IP Address
  """
  @spec to_bits(ip) :: String.t
  def to_bits(ip)

  def to_bits(mask) when is_integer(mask), do: do_to_bits(mask, SubnetError)
  def to_bits(addr), do: do_to_bits(addr, IPError)

  defp do_to_bits(ip, error) do
    ip_list = if pre_transformation_validations(ip) do
      ip |> to_octet_list
    else
      raise error
    end
    if validate_octet_list(ip_list) do
      transform_addr(ip_list, 2, 8, ".", "")
    else
      raise error
    end
  end

  @doc """
  Converts CIDR, binary, hexadecimal, dotted binary and tuple
  notation IP address/subnet mask to a `0x` prefixed hexadecimal
  number.

  ## Example

      iex> IPA.to_hex({192, 168, 0, 1})
      "0xC0A80001"
      iex> IPA.to_hex("255.255.255.0")
      "0xFFFFFF00"
      iex> IPA.to_hex("192.168.0.1")
      "0xC0A80001"
      iex> IPA.to_hex("0b11000000101010000000000000000001")
      "0xC0A80001"
      iex> IPA.to_hex("11000000.10101000.00000000.00000001")
      "0xC0A80001"
      iex> IPA.to_hex(24)
      "0xFFFFFF00"
      iex> IPA.to_hex("192.168.0.256")
      ** (IPError) Invalid IP Address
  """
  @spec to_hex(ip) :: String.t
  def to_hex(ip)

  def to_hex(mask) when is_integer(mask), do: do_to_hex(mask, SubnetError)
  def to_hex(addr), do: do_to_hex(addr, IPError)

  defp do_to_hex(ip, error) do
    ip_list = if pre_transformation_validations(ip) do
      ip |> to_octet_list
    else
      raise error
    end
    if validate_octet_list(ip_list) do
      transform_addr(ip_list, 16, 2, "", "0x")
    else
      raise error
    end
  end

  @doc """
  Converts a dotted decimal IP address or Subnet Mask, or a
  CIDR notation Subnet Mask, to a 4 element tuple, representing
  the 4 octets.

  ## Example

      iex> IPA.to_octets("192.168.0.1")
      {192, 168, 0, 1}
      iex> IPA.to_octets("255.255.255.0")
      {255, 255, 255, 0}
      iex> IPA.to_octets("0b11000000101010000000000000000001")
      {192, 168, 0, 1}
      iex> IPA.to_octets("0xC0A80001")
      {192, 168, 0, 1}
      iex> IPA.to_octets("11000000.10101000.00000000.00000001")
      {192, 168, 0, 1}
      iex> IPA.to_octets(24)
      {255, 255, 255, 0}
      iex> IPA.to_octets("192.168.0.256")
      ** (IPError) Invalid IP Address
  """
  @spec to_octets(ip) :: {integer}
  def to_octets(ip)

  def to_octets(mask) when is_integer(mask), do: do_to_octets(mask, SubnetError)
  def to_octets(addr), do: do_to_octets(addr, IPError)

  defp do_to_octets(ip, error) do
    ip_list = if pre_transformation_validations(ip) do
      ip |> to_octet_list
    else
      raise error
    end
    if validate_octet_list(ip_list) do
      List.to_tuple(ip_list)
    else
      raise error
    end
  end

  @doc """
  Converts a dotted decimal, hex, binary, tuple & dotted binary
  Subnet Mask to CIDR notation.

  ## Examples

      iex> IPA.to_cidr("255.255.255.0")
      24
      iex> IPA.to_cidr("0xFFFFFF00")
      24
      iex> IPA.to_cidr("0b11111111111111111111111100000000")
      24
      iex> IPA.to_cidr({255, 255, 255, 0})
      24
      iex> IPA.to_cidr("11111111.11111111.11111111.00000000")
      24
      iex> IPA.to_cidr("192.168.0.1")
      ** (SubnetError) Invalid Subnet Mask
  """
  def to_cidr(mask) do
    bits_mask = mask_to_bits(mask)
    if valid_mask?(bits_mask) do
      transform_to_cidr(bits_mask)
    else
      raise SubnetError
    end
  end

  @doc """
  Checks whether a given IP address is reserved.

  ## Examples

      iex> IPA.reserved?("192.168.0.1")
      true
      iex> IPA.reserved?("8.8.8.8")
      false
  """
  @spec reserved?(String.t) :: boolean
  def reserved?(addr) do
    case block(addr) do
      :public -> false
      _ -> true
    end
  end

  @doc """
  Returns an atom describing which reserved block the address is a member of if it is a private address, returns `:public` otherwise.

  [Available blocks](https://en.wikipedia.org/wiki/Reserved_IP_addresses):

  | Atom | Range(s) | Purpose |
  |:----:|:--------:|:-------:|
  | `:this_network` | `0.0.0.0/8` | Used for broadcast messages to the current "this" network as specified by RFC 1700, page 4. |
  | `:rfc1918` | `10.0.0.0/8` `172.16.0.0/12` `192.168.0.0/16` | Used for local communications within a private network as specified by RFC 1918. |
  | `:rfc6598` | `100.64.0.0/10` | Used for communications between a service provider and its subscribers when using a Carrier-grade NAT, as specified by RFC 6598. |
  | `:loopback` | `127.0.0.0/8` | Used for loopback addresses to the local host, as specified by RFC 990. |
  | `:link_local` | `169.254.0.0/16` | Used for link-local addresses between two hosts on a single link when no IP address is otherwise specified, such as would have normally been retrieved from a DHCP server, as specified by RFC 3927. |
  | `:rfc5736` | `192.0.0.0/24` | Used for the IANA IPv4 Special Purpose Address Registry as specified by RFC 5736. |
  | `:rfc5737` | `192.0.2.0/24` `198.51.100.0/24` `203.0.113.0/24` | Assigned as "TEST-NET" in RFC 5737 for use solely in documentation and example source code and should not be used publicly. |
  | `:rfc3068` | `192.88.99.0/24` | Used by 6to4 anycast relays as specified by RFC 3068. |
  | `:rfc2544` | `198.18.0.0/15` | Used for testing of inter-network communications between two separate subnets as specified in RFC 2544. |
  | `:multicast` | `224.0.0.0/4` | Reserved for multicast assignments as specified in RFC 5771. `233.252.0.0/24` is assigned as "MCAST-TEST-NET" for use solely in documentation and example source code. |
  | `:future` | `240.0.0.0/4` | Reserved for future use, as specified by RFC 6890. |
  | `:limited_broadcast` | `255.255.255.255/32` | Reserved for the "limited broadcast" destination address, as specified by RFC 6890. |
  | `:public` | | All other addresses are public. |

  ## Examples

      iex> IPA.block("8.8.8.8")
      :public
      iex> IPA.block("192.168.0.1")
      :rfc1918
  """
  @spec block(String.t) :: atom
  def block(addr) do
    addr
    |> to_octets
    |> which_block?
  end

  # this whole pre-transformations validations feels REALLY clunky
  # a series of basic validity checks before transforming to list of octets
  defp pre_transformation_validations(addr) when is_tuple(addr), do: true
  defp pre_transformation_validations(mask) when is_integer(mask) do
    if mask < 33 and mask > 0, do: true, else: false
  end
  defp pre_transformation_validations(addr) do
    cond do
      String.at(addr, 1) == "b" and String.length(addr) != 34 -> false
      String.at(addr, 1) == "b" and not just_ones_and_zeroes?(addr) -> false
      number_of_dots(addr) > 3 -> false
      String.length(addr) == 35 and not just_ones_and_zeroes?(String.replace(addr, ".", "")) -> false
      String.at(addr, 1) == "x" and String.length(addr) != 10 -> false
      true -> true
    end
  end

  # funnel different notation types to the appropriate means
  # of transforming to a 4-element list of octets
  defp to_octet_list(ip) do
    cond do
      is_integer(ip) ->
        int_to_octet_list(ip)
      is_tuple(ip) ->
        Tuple.to_list(ip)
      String.at(ip, 1) == "x" ->
        hex_to_octet_list(ip)
      String.at(ip, 1) == "b" ->
        bin_to_octet_list(ip)
      String.contains?(ip, ".") ->
        dotted_to_octet_list(ip)
      true ->
        false
    end
  end

  # transform an integer (cidr notation mask) to a 4-element list of octets
  defp int_to_octet_list(mask) do
    (List.duplicate(255, div(mask, 8)) ++ Enum.at(@mask_bits, rem(mask, 8)))
    |> add_zero_bits
  end

  # transform a hexidecimal ip address to a 4-element list of octets
  defp hex_to_octet_list(addr) do
    <<48, 120, a::binary-size(2), b::binary-size(2), c::binary-size(2), d::binary-size(2)>> = addr
    [a, b, c, d]
    |> Enum.map(&String.to_integer(&1, 16))
  end

  # transform a hexidecimal ip address to a 4-element list of octets
  defp bin_to_octet_list(addr) do
    <<48, 98, a::binary-size(8), b::binary-size(8), c::binary-size(8), d::binary-size(8)>> = addr
    [a, b, c, d]
    |> Enum.map(&String.to_integer(&1, 2))
  end

  # check a binary number contains only 1 or 0
  defp just_ones_and_zeroes?(bin) do
    bin
    |> String.slice(2..-1)
    |> String.graphemes
    |> Enum.all?(fn(x) -> x == "0" || x == "1" end)
  end

  # transform a dotted decimal ip address to a 4-element list of octets
  defp dotted_to_octet_list(addr) do
    addr = String.split(addr, ".")
    if Enum.any?(addr, fn(x) -> String.length(x) > 3 end) do
      Enum.map(addr, &String.to_integer(&1, 2))
    else
      Enum.map(addr, &String.to_integer/1)
    end
  end

  # validate each of the 4 elements in a list of octets
  defp validate_octet_list(addr) when length(addr) === 4 do
    Enum.all?(addr, fn x -> x > -1 && x < 256 end)
  end
  defp validate_octet_list(_), do: false

  # find out how many dots are in the given ip address
  defp number_of_dots(addr) do
    addr |> String.replace(~r/[^\.]/, "") |> String.length
  end

  # transform a subnet mask into dotted binary notation
  defp mask_to_bits(mask) do
    mask |> to_octet_list |> transform_addr(2, 8, ".", "")
  end

  # transform a binary address to cidr notation
  defp transform_to_cidr(bin) do
    bin
    |> String.replace(~r/\.|0/, "")
    |> String.length
  end

  # Check to make sure that 1s don't follow 0s
  # or that the mask doesn't start with a 0
  defp binary_validation(_, [], _), do: true
  defp binary_validation(?0, _, []), do: false
  defp binary_validation(?1, _, ?0), do: false
  defp binary_validation(?1, [h|t], _) do
    binary_validation(h, t, ?1)
  end
  defp binary_validation(?0, [h|t], _) do
    binary_validation(h, t, ?0)
  end

  # add as many zeroes as necessary to an octets list until it contains 4 elements
  defp add_zero_bits(octets_list) when length(octets_list) == 4, do: octets_list
  defp add_zero_bits(octets_list) do
    add_zero_bits(octets_list ++ [0])
  end

  # Convert address to different numerical base,
  # (ie. 2 for binary, 16 for hex), left-pads,
  # joins and adds a prefix
  defp transform_addr(addr, base, max_length, joiner, prefix) do
    addr
    |> Stream.map(&Integer.to_string(&1, base))
    |> Stream.map(&left_pad(&1, max_length, "0"))
    |> Enum.join(joiner)
    |> String.replace_prefix("", prefix)
  end

  # When numbers are converted from decimal to binary/hex
  # any leading zeroes are discarded, so we need to left-pad
  # them to their expected length (ie. 8 for binary, 2 for hex)
  defp left_pad(n, max_len, _) when byte_size(n) == byte_size(max_len), do: n
  defp left_pad(n, max_len, char), do: String.pad_leading(n, max_len, char)

  # discover which block an ip address belongs to
  defp which_block?({0, _, _, _}),                                      do: :this_network
  defp which_block?({10, _, _, _}),                                     do: :rfc1918
  defp which_block?({100, b, _, _}) when b > 63 and b < 128,            do: :rfc6598
  defp which_block?({127, _, _, _}),                                    do: :loopback
  defp which_block?({169, 254, _, _}),                                  do: :link_local
  defp which_block?({172, b, _, _}) when b > 15 and b < 32,             do: :rfc1918
  defp which_block?({192, 0, 0, _}),                                    do: :rfc5736
  defp which_block?({192, 0, 2, 0}),                                    do: :rfc5737
  defp which_block?({192, 88, 99, _}),                                  do: :rfc3068
  defp which_block?({192, 168, _, _}),                                  do: :rfc1918
  defp which_block?({198, b, _, _}) when b > 17 and b < 20,             do: :rfc2544
  defp which_block?({198, 51, 100, _}),                                 do: :rfc5737
  defp which_block?({203, 0, 113, _}),                                  do: :rfc5737
  defp which_block?({a, _, _, _}) when a > 223 and a < 240,             do: :multicast
  defp which_block?({a, _, _, d}) when a > 239 and a < 256 and d < 255, do: :future
  defp which_block?({255, 255, 255, 255}),                              do: :limited_broadcast
  defp which_block?(_),                                                 do: :public
end

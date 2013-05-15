require 'minitest/autorun'
require 'marshal/structure'
require 'ben_string'
require 'openssl'
require 'pp'

class OpenSSL::X509::Name
  alias _dump_data to_a

  def _load_data ary
    ary.each do |entry|
      add_entry(*entry)
    end
  end
end

class B; end

module C; end

module E; end

class M
  def marshal_dump
    'marshal_dump'
  end

  def marshal_load o
  end
end

class U
  def self._load str
    new
  end

  def _dump limit
    s = '_dump'
    s.instance_variable_set :@ivar_on_dump_str, 'value on ivar on dump str'
    s
  end
end

S = Struct.new :f

class TestMarshalStructure < MiniTest::Unit::TestCase

  def mu_pp obj
    s = ''
    s = PP.pp obj, s
    s.chomp
  end

  def setup
    @MS = Marshal::Structure
  end

  def test_construct
    str =
      "\004\b{\006:\006a[\031c\006Bm\006C\"\006d/\006e\000i\006" \
     "f\0322.2999999999999998\000ff" \
     "l+\n\000\000\000\000\000\000\000\000\001\0000TF}\000i\000" \
     "S:\006S\006:\006fi\000o:\vObject\000@\017" \
     "U:\006M\"\021marshal_dump" \
     "Iu:\006U\n_dump\006" \
     ":\026@ivar_on_dump_str\"\036value on ivar on dump str" \
     ";\000e:\006Eo;\b\000" \
     "I\"\025string with ivar\006:\v@value\"\017some value" \
     "C:\016BenString\"\000"

    structure = @MS.load str

    expected = [
      :hash,
      0,
      1,
      [:symbol, 0, "a"],
      [:array,
        1,
        20,
        [:class, 2, "B"],
        [:module, 3, "C"],
        [:string, 4, "d"],
        [:regexp, 5, "e", 0],
        [:fixnum, 1],
        [:float, 6, "2.2999999999999998\000ff"],
        [:bignum, 7, 1, 10, 18446744073709551616],
        :nil,
        :true,
        :false,
        [:hash_default, 8, 0, [:fixnum, 0]],
        [:struct, 9, [:symbol, 1, "S"], 1, [:symbol, 2, "f"], [:fixnum, 0]],
        [:object, 10, [:symbol, 3, "Object"], [0]],
        [:link, 10],
        [:user_marshal, 11, [:symbol, 4, "M"], [:string, 12, "marshal_dump"]],
        [:instance_variables,
          [:user_defined, 13, [:symbol, 5, "U"], "_dump"],
          1,
          [:symbol, 6, "@ivar_on_dump_str"],
          [:string, 14, "value on ivar on dump str"]],
          [:symbol_link, 0],
          [:extended, [:symbol, 7, "E"], [:object, 15, [:symbol_link, 3], [0]]],
          [:instance_variables,
            [:string, 16, "string with ivar"],
            1,
            [:symbol, 8, "@value"],
            [:string, 17, "some value"]],
            [:user_class, [:symbol, 9, "BenString"], [:string, 18, ""]]]]

    assert_equal expected, structure
  end

  def test_construct_too_short
    str = "\x04\x08{"

    e = assert_raises ArgumentError do
      @MS.load str
    end

    assert_equal 'marshal data too short', e.message
  end

  def test_construct_data
    name = OpenSSL::X509::Name.parse 'CN=nobody/DC=example'
    str = Marshal.dump name

    expected = [
      :data,
      0,
      [:symbol, 0, "OpenSSL::X509::Name"],
      [:array,
        1,
        2,
        [:array, 2, 3,
          [:string, 3, "CN"],
          [:string, 4, "nobody"],
          [:fixnum, 12]],
        [:array, 5, 3,
          [:string, 6, "DC"],
          [:string, 7, "example"],
          [:fixnum, 22]]]]

        assert_equal expected, @MS.load(str)
  end

  def test_construct_module_old
    assert_equal [:module, 0, "M"], @MS.load("\x04\x08M\x06M")
  end

  def test_consume
    ms = @MS.new "\x04\x08\x06M"

    assert_equal "\x06M", ms.consume(2)
  end

  def test_consume_bytes
    ms = @MS.new "\x04\x08\x06M"

    assert_equal [6, 77], ms.consume_bytes(2)

    e = assert_raises Marshal::Structure::EndOfMarshal do
      ms.consume_bytes 3
    end

    assert_equal 4, e.consumed
    assert_equal 3, e.requested
  end

  def test_consume_byte
    ms = @MS.new "\x04\x08M"

    assert_equal 77, ms.consume_byte

    e = assert_raises Marshal::Structure::EndOfMarshal do
      ms.consume_byte
    end

    assert_equal 3, e.consumed
    assert_equal 1, e.requested
  end

  def test_consume_character
    ms = @MS.new "\x04\x08M"

    assert_equal 'M', ms.consume_character

    e = assert_raises Marshal::Structure::EndOfMarshal do
      ms.consume_character
    end

    assert_equal 3, e.consumed
    assert_equal 1, e.requested
  end

  def test_construct_integer
    assert_equal        0, @MS.new("\x04\x08\x00").construct_integer

    assert_equal        0, @MS.new("\x04\x08\x01\x00").construct_integer
    assert_equal        1, @MS.new("\x04\x08\x01\x01").construct_integer
    assert_equal        0, @MS.new("\x04\x08\x02\x00\x00").construct_integer
    assert_equal     2<<7, @MS.new("\x04\x08\x02\x00\x01").construct_integer
    assert_equal        0, @MS.new("\x04\x08\x03\x00\x00\x00").construct_integer
    assert_equal    2<<15, @MS.new("\x04\x08\x03\x00\x00\x01").construct_integer
    assert_equal        0,
                 @MS.new("\x04\x08\x04\x00\x00\x00\x00").construct_integer
    assert_equal    2<<23,
                 @MS.new("\x04\x08\x04\x00\x00\x00\x01").construct_integer
    assert_equal (2<<31) - 1,
                 @MS.new("\x04\x08\x04\xff\xff\xff\xff").construct_integer

    assert_equal        0, @MS.new("\x04\x08\x05").construct_integer
    assert_equal        1, @MS.new("\x04\x08\x06").construct_integer
    assert_equal      122, @MS.new("\x04\x08\x7f").construct_integer
    assert_equal     -123, @MS.new("\x04\x08\x80").construct_integer
    assert_equal       -1, @MS.new("\x04\x08\xfa").construct_integer
    assert_equal        0, @MS.new("\x04\x08\xfb").construct_integer

    assert_equal -(1<<32),
                 @MS.new("\x04\x08\xfc\x00\x00\x00\x00").construct_integer
    assert_equal       -1,
                 @MS.new("\x04\x08\xfc\xff\xff\xff\xff").construct_integer
    assert_equal -(1<<24), @MS.new("\x04\x08\xfd\x00\x00\x00").construct_integer
    assert_equal       -1, @MS.new("\x04\x08\xfd\xff\xff\xff").construct_integer
    assert_equal -(1<<16), @MS.new("\x04\x08\xfe\x00\x00").construct_integer
    assert_equal       -1, @MS.new("\x04\x08\xfe\xff\xff").construct_integer
    assert_equal  -(1<<8), @MS.new("\x04\x08\xff\x00").construct_integer
    assert_equal       -1, @MS.new("\x04\x08\xff\xff").construct_integer
  end

  def test_get_byte_sequence
    ms = @MS.new "\x04\x08\x06M"

    assert_equal "M", ms.get_byte_sequence
  end

  def test_tokens_array
    ms = @MS.new "\x04\x08[\x07TF"

    assert_equal [:array, 2, :true, :false], ms.tokens.to_a
  end

  def test_tokens_bignum
    ms = @MS.new "\x04\x08l-\x07\x00\x00\x00@"

    assert_equal [:bignum, -1073741824], ms.tokens.to_a
  end

  def test_tokens_class
    ms = @MS.new "\x04\x08c\x06C"

    assert_equal [:class, 'C'], ms.tokens.to_a
  end

  def test_tokens_data
    ms = @MS.new "\x04\bd:\x18OpenSSL::X509::Name[\x00"

    assert_equal [:data, :symbol, 'OpenSSL::X509::Name', :array, 0],
                 ms.tokens.to_a
  end

  def test_tokens_extended
    skip 'todo'
    ms = @MS.new "\x04\be:\x0FEnumerableo:\vObject\x00"

    expected = [
      :extended, :symbol, 'Enumerable',
      :object, :symbol, 'Object', 0
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_false
    ms = @MS.new "\x04\x080"

    assert_equal [:nil], ms.tokens.to_a
  end

  def test_tokens_fixnum
    ms = @MS.new "\x04\x08i/"

    assert_equal [:fixnum, 42], ms.tokens.to_a
  end

  def test_tokens_float
    ms = @MS.new "\x04\bf\b4.2"

    assert_equal [:float, '4.2'], ms.tokens.to_a
  end

  def test_tokens_hash
    ms = @MS.new "\x04\b{\ai\x06i\aTF"

    assert_equal [:hash, 2, :fixnum, 1, :fixnum, 2, :true, :false],
                 ms.tokens.to_a
  end

  def test_tokens_hash_default
    ms = @MS.new "\x04\x08}\x00i\x06"

    assert_equal [:hash_default, 0, :fixnum, 1], ms.tokens.to_a
  end

  def test_tokens_instance_variables
    ms = @MS.new "\x04\bI\"\x00\a:\x06ET:\a@xi\a"

    expected = [
      :instance_variables,
      :string, '',
      2, :symbol, 'E', :true, :symbol, '@x', :fixnum, 2,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_link
    ms = @MS.new "\x04\x08[\x07I\"\x00\x06:\x06ET@\x06"

    expected = [
      :array, 2,
        :instance_variables,
          :string, '',
          1,
          :symbol, 'E', :true,
        :link, 1,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_module
    ms = @MS.new "\x04\bm\x0FEnumerable"

    assert_equal [:module, 'Enumerable'], ms.tokens.to_a
  end

  def test_tokens_module_old
    ms = @MS.new "\x04\bM\x0FEnumerable"

    assert_equal [:module_old, 'Enumerable'], ms.tokens.to_a
  end

  def test_tokens_object
    ms = @MS.new "\x04\bo:\vObject\x00"

    assert_equal [:object, :symbol, 'Object', 0], ms.tokens.to_a
  end

  def test_tokens_regexp
    ms = @MS.new "\x04\bI/\x06x\x01\x06:\x06EF"

    expected = [
      :instance_variables,
          :regexp, 'x', 1,
        1, :symbol, 'E', :false,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_string
    ms = @MS.new "\x04\b\"\x06x"

    assert_equal [:string, 'x'], ms.tokens.to_a
  end

  def test_tokens_struct
    ms = @MS.new "\x04\x08S:\x06S\x06:\x06ai\x08"

    expected = [
      :struct, :symbol, 'S', 1, :symbol, 'a', :fixnum, 3
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_symbol
    ms = @MS.new "\x04\x08:\x06S"

    expected = [
      :symbol, 'S'
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_symbol_link
    ms = @MS.new "\x04\b[\a:\x06s;\x00"

    expected = [
      :array, 2, :symbol, 's', :symbol_link, 0,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_true
    ms = @MS.new "\x04\x08T"

    assert_equal [:true], ms.tokens.to_a
  end

  def test_tokens_user_defined
    ms = @MS.new "\x04\bIu:\tTime\r\xE7Q\x1C\x80\xA8\xC3\x83\xE5\a" \
                 ":\voffseti\xFE\x90\x9D:\tzoneI\"\bPDT\x06:\x06ET"

    timeval = "\xE7Q\x1C\x80\xA8\xC3\x83\xE5"
    timeval.force_encoding Encoding::BINARY

    expected = [
      :instance_variables,
          :user_defined, :symbol, 'Time', timeval,
        2,
          :symbol, 'offset', :fixnum, -25200,
          :symbol, 'zone',
            :instance_variables,
                :string, 'PDT',
              1, :symbol, 'E', :true,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_user_marshal
    ms = @MS.new "\x04\bU:\tDate[\vi\x00i\x03l{%i\x00i\x00i\x00f\f2299161"

    expected = [
      :user_marshal, :symbol, 'Date',
        :array, 6,
          :fixnum, 0,
          :fixnum, 2456428,
          :fixnum, 0,
          :fixnum, 0,
          :fixnum, 0,
          :float, '2299161',
    ]

    assert_equal expected, ms.tokens.to_a
  end

end


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

class TestMarshalStructureParser < MiniTest::Unit::TestCase

  def mu_pp obj
    s = ''
    s = PP.pp obj, s
    s.chomp
  end

  def setup
    @MS = Marshal::Structure
  end

  def test_parse
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

    structure = parse str

    float_data = "2.2999999999999998\x00ff"
    float_data.force_encoding Encoding::BINARY

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
        [:float, 6, float_data],
        [:bignum, 7, 18446744073709551616],
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

  def test_parse_too_short
    str = "\x04\x08{"

    e = assert_raises ArgumentError do
      parse str
    end

    assert_equal 'marshal data too short', e.message
  end

  def test_parse_data
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

    assert_equal expected, parse(str)
  end

  def test_parse_module_old
    assert_equal [:module, 0, "M"], parse("\x04\x08M\x06M")
  end

  def parse marshal
    tokenizer = @MS::Tokenizer.new marshal

    parser = @MS::Parser.new tokenizer

    parser.parse
  end

end


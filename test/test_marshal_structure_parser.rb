require 'marshal/structure/test_case'

class TestMarshalStructureParser < Marshal::Structure::TestCase

  def test_parse
    structure = parse EVERYTHING

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
        [:hash_default, 8, 2,
          [:fixnum, 1], [:fixnum, 2],
          :true, :false,
          [:fixnum, 404]],
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

    parser = @MS::Parser.new tokenizer.tokens

    parser.parse
  end

end


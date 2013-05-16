require 'minitest/autorun'
require 'marshal/structure'
require 'pp'

class TestMarshalStructureTokenizer < MiniTest::Unit::TestCase

  def mu_pp obj
    s = ''
    s = PP.pp obj, s
    s.chomp
  end

  def setup
    @MST = Marshal::Structure::Tokenizer
  end

  def test_consume
    ms = @MST.new "\x04\x08\x06M"

    assert_equal "\x06M", ms.consume(2)
  end

  def test_consume_bytes
    ms = @MST.new "\x04\x08\x06M"

    assert_equal [6, 77], ms.consume_bytes(2)

    e = assert_raises Marshal::Structure::EndOfMarshal do
      ms.consume_bytes 3
    end

    assert_equal 4, e.consumed
    assert_equal 3, e.requested
  end

  def test_consume_byte
    ms = @MST.new "\x04\x08M"

    assert_equal 77, ms.consume_byte

    e = assert_raises Marshal::Structure::EndOfMarshal do
      ms.consume_byte
    end

    assert_equal 3, e.consumed
    assert_equal 1, e.requested
  end

  def test_consume_character
    ms = @MST.new "\x04\x08M"

    assert_equal 'M', ms.consume_character

    e = assert_raises Marshal::Structure::EndOfMarshal do
      ms.consume_character
    end

    assert_equal 3, e.consumed
    assert_equal 1, e.requested
  end

  def test_construct_integer
    assert_equal        0, @MST.new("\x04\x08\x00").construct_integer

    assert_equal        0, @MST.new("\x04\x08\x01\x00").construct_integer
    assert_equal        1, @MST.new("\x04\x08\x01\x01").construct_integer
    assert_equal        0, @MST.new("\x04\x08\x02\x00\x00").construct_integer
    assert_equal     2<<7, @MST.new("\x04\x08\x02\x00\x01").construct_integer
    assert_equal        0,
                 @MST.new("\x04\x08\x03\x00\x00\x00").construct_integer
    assert_equal    2<<15,
                 @MST.new("\x04\x08\x03\x00\x00\x01").construct_integer
    assert_equal        0,
                 @MST.new("\x04\x08\x04\x00\x00\x00\x00").construct_integer
    assert_equal    2<<23,
                 @MST.new("\x04\x08\x04\x00\x00\x00\x01").construct_integer
    assert_equal (2<<31) - 1,
                 @MST.new("\x04\x08\x04\xff\xff\xff\xff").construct_integer

    assert_equal        0, @MST.new("\x04\x08\x05").construct_integer
    assert_equal        1, @MST.new("\x04\x08\x06").construct_integer
    assert_equal      122, @MST.new("\x04\x08\x7f").construct_integer
    assert_equal(    -123, @MST.new("\x04\x08\x80").construct_integer)
    assert_equal(      -1, @MST.new("\x04\x08\xfa").construct_integer)
    assert_equal        0, @MST.new("\x04\x08\xfb").construct_integer

    assert_equal(-(1<<32),
                 @MST.new("\x04\x08\xfc\x00\x00\x00\x00").construct_integer)
    assert_equal(      -1,
                 @MST.new("\x04\x08\xfc\xff\xff\xff\xff").construct_integer)
    assert_equal(-(1<<24),
                 @MST.new("\x04\x08\xfd\x00\x00\x00").construct_integer)
    assert_equal(      -1,
                 @MST.new("\x04\x08\xfd\xff\xff\xff").construct_integer)
    assert_equal(-(1<<16), @MST.new("\x04\x08\xfe\x00\x00").construct_integer)
    assert_equal(      -1, @MST.new("\x04\x08\xfe\xff\xff").construct_integer)
    assert_equal( -(1<<8), @MST.new("\x04\x08\xff\x00").construct_integer)
    assert_equal(      -1, @MST.new("\x04\x08\xff\xff").construct_integer)
  end

  def test_get_byte_sequence
    ms = @MST.new "\x04\x08\x06M"

    assert_equal "M", ms.get_byte_sequence
  end

  def test_tokens_array
    ms = @MST.new "\x04\x08[\x07TF"

    assert_equal [:array, 2, :true, :false], ms.tokens.to_a
  end

  def test_tokens_bignum
    ms = @MST.new "\x04\x08l-\x07\x00\x00\x00@"

    assert_equal [:bignum, -1073741824], ms.tokens.to_a
  end

  def test_tokens_class
    ms = @MST.new "\x04\x08c\x06C"

    assert_equal [:class, 'C'], ms.tokens.to_a
  end

  def test_tokens_data
    ms = @MST.new "\x04\bd:\x18OpenSSL::X509::Name[\x00"

    assert_equal [:data, :symbol, 'OpenSSL::X509::Name', :array, 0],
                 ms.tokens.to_a
  end

  def test_tokens_extended
    skip 'todo'
    ms = @MST.new "\x04\be:\x0FEnumerableo:\vObject\x00"

    expected = [
      :extended, :symbol, 'Enumerable',
      :object, :symbol, 'Object', 0
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_false
    ms = @MST.new "\x04\x080"

    assert_equal [:nil], ms.tokens.to_a
  end

  def test_tokens_fixnum
    ms = @MST.new "\x04\x08i/"

    assert_equal [:fixnum, 42], ms.tokens.to_a
  end

  def test_tokens_float
    ms = @MST.new "\x04\bf\b4.2"

    assert_equal [:float, '4.2'], ms.tokens.to_a
  end

  def test_tokens_hash
    ms = @MST.new "\x04\b{\ai\x06i\aTF"

    assert_equal [:hash, 2, :fixnum, 1, :fixnum, 2, :true, :false],
                 ms.tokens.to_a
  end

  def test_tokens_hash_default
    ms = @MST.new "\x04\x08}\x00i\x06"

    assert_equal [:hash_default, 0, :fixnum, 1], ms.tokens.to_a
  end

  def test_tokens_instance_variables
    ms = @MST.new "\x04\bI\"\x00\a:\x06ET:\a@xi\a"

    expected = [
      :instance_variables,
      :string, '',
      2, :symbol, 'E', :true, :symbol, '@x', :fixnum, 2,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_link
    ms = @MST.new "\x04\x08[\x07I\"\x00\x06:\x06ET@\x06"

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
    ms = @MST.new "\x04\bm\x0FEnumerable"

    assert_equal [:module, 'Enumerable'], ms.tokens.to_a
  end

  def test_tokens_module_old
    ms = @MST.new "\x04\bM\x0FEnumerable"

    assert_equal [:module_old, 'Enumerable'], ms.tokens.to_a
  end

  def test_tokens_object
    ms = @MST.new "\x04\bo:\vObject\x00"

    assert_equal [:object, :symbol, 'Object', 0], ms.tokens.to_a
  end

  def test_tokens_regexp
    ms = @MST.new "\x04\bI/\x06x\x01\x06:\x06EF"

    expected = [
      :instance_variables,
          :regexp, 'x', 1,
        1, :symbol, 'E', :false,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_string
    ms = @MST.new "\x04\b\"\x06x"

    assert_equal [:string, 'x'], ms.tokens.to_a
  end

  def test_tokens_struct
    ms = @MST.new "\x04\x08S:\x06S\x06:\x06ai\x08"

    expected = [
      :struct, :symbol, 'S', 1, :symbol, 'a', :fixnum, 3
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_symbol
    ms = @MST.new "\x04\x08:\x06S"

    expected = [
      :symbol, 'S'
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_symbol_link
    ms = @MST.new "\x04\b[\a:\x06s;\x00"

    expected = [
      :array, 2, :symbol, 's', :symbol_link, 0,
    ]

    assert_equal expected, ms.tokens.to_a
  end

  def test_tokens_too_short
    ms = @MST.new "\x04\x08"

    assert_raises Marshal::Structure::EndOfMarshal do
      ms.tokens.to_a
    end
  end

  def test_tokens_true
    ms = @MST.new "\x04\x08T"

    assert_equal [:true], ms.tokens.to_a
  end

  def test_tokens_user_defined
    ms = @MST.new "\x04\bIu:\tTime\r\xE7Q\x1C\x80\xA8\xC3\x83\xE5\a" \
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
    ms = @MST.new "\x04\bU:\tDate[\vi\x00i\x03l{%i\x00i\x00i\x00f\f2299161"

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


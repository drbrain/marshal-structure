require 'marshal/structure/test_case'

class TestMarshalStructureAllocationCounter < Marshal::Structure::TestCase

  def test_count
    count = count_allocations EVERYTHING

    assert_equal 21, count
  end

  def test_tokens_array
    count = count_allocations "\x04\x08[\x07TF"

    assert_equal 1, count
  end

  def test_tokens_bignum
    count = count_allocations "\x04\x08l-\x07\x00\x00\x00@"

    assert_equal 1, count
  end

  def test_tokens_class
    count = count_allocations "\x04\x08c\x06C"

    assert_equal 0, count
  end

  def test_tokens_data
    count = count_allocations "\x04\bd:\x18OpenSSL::X509::Name[\x00"

    assert_equal 2, count
  end

  def test_tokens_extended
    count = count_allocations "\x04\be:\x0FEnumerableo:\vObject\x00"

    assert_equal 1, count
  end

  def test_tokens_false
    count = count_allocations "\x04\x080"

    assert_equal 0, count
  end

  def test_tokens_fixnum
    count = count_allocations "\x04\x08i/"

    assert_equal 0, count
  end

  def test_tokens_float
    count = count_allocations "\x04\bf\b4.2"

    assert_equal 1, count
  end

  def test_tokens_hash
    count = count_allocations "\x04\b{\ai\x06i\aTF"

    assert_equal 1, count
  end

  def test_tokens_hash_default
    count = count_allocations "\x04\x08}\x00i\x06"

    assert_equal 1, count
  end

  def test_tokens_instance_variables
    count = count_allocations "\x04\bI\"\x00\a:\x06ET:\a@xi\a"

    assert_equal 3, count
  end

  def test_tokens_link
    count = count_allocations "\x04\x08[\x07I\"\x00\x06:\x06ET@\x06"

    assert_equal 3, count
  end

  def test_tokens_module
    count = count_allocations "\x04\bm\x0FEnumerable"

    assert_equal 0, count
  end

  def test_tokens_module_old
    count = count_allocations "\x04\bM\x0FEnumerable"

    assert_equal 0, count
  end

  def test_tokens_allocation
    count = count_allocations "\x04\bo:\vObject\x00"

    assert_equal 1, count
  end

  def test_tokens_regexp
    count = count_allocations "\x04\bI/\x06x\x01\x06:\x06EF"

    assert_equal 2, count
  end

  def test_tokens_string
    count = count_allocations "\x04\b\"\x06x"

    assert_equal 1, count
  end

  def test_tokens_struct
    count = count_allocations "\x04\x08S:\x06S\x06:\x06ai\x08"

    assert_equal 2, count
  end

  def test_tokens_symbol
    count = count_allocations "\x04\x08:\x06S"

    assert_equal 1, count
  end

  def test_tokens_symbol_link
    count = count_allocations "\x04\b[\a:\x06s;\x00"

    assert_equal 2, count
  end

  def test_tokens_true
    count = count_allocations "\x04\x08T"

    assert_equal 0, count
  end

  def test_tokens_user_defined
    count = count_allocations "\x04\bIu:\tTime\r\xE7Q\x1C\x80\xA8\xC3\x83\xE5\a" \
                          ":\voffseti\xFE\x90\x9D:\tzoneI\"\bPDT\x06:\x06ET"

    timeval = "\xE7Q\x1C\x80\xA8\xC3\x83\xE5"
    timeval.force_encoding Encoding::BINARY

    assert_equal 6, count
  end

  def test_tokens_user_marshal
    count =
      count_allocations "\x04\bU:\tDate[\vi\x00i\x03l{%i\x00i\x00i\x00f\f2299161"

    assert_equal 3, count
  end

  def count_allocations marshal
    tokenizer = @MS::Tokenizer.new marshal

    allocation_counter = @MS::AllocationCounter.new tokenizer.tokens

    allocation_counter.count
  end

end


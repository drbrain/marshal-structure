require 'marshal/structure/test_case'

class TestMarshalStructure < Marshal::Structure::TestCase

  def test_class_load
    ary = %W[\x04 \x08 T]
    def ary.getc
      shift
    end

    result = @MS.load ary

    assert_equal :true, result
  end

  def test_count_allocations
    assert_equal 1, @MS.new("\x04\x08[\x06T").count_allocations
  end

  def test_structure
    assert_equal [:array, 0, 1, :true], @MS.new("\x04\x08[\x06T").structure
  end

  def test_token_stream
    stream = @MS.new("\x04\x08[\x06T").token_stream

    assert_kind_of Enumerator, stream

    assert_equal [:array, 1, :true], stream.to_a
  end

end


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

end


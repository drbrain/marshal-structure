require 'minitest/autorun'
require 'marshal/structure'

class TestMarshalStructure < MiniTest::Unit::TestCase

  def mu_pp obj
    s = ''
    s = PP.pp obj, s
    s.chomp
  end

  def setup
    @MS = Marshal::Structure
  end

  def test_class_load
    ary = %W[\x04 \x08 T]
    def ary.getc
      shift
    end

    result = @MS.load ary

    assert_equal :true, result
  end

end


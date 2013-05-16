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

class Marshal::Structure::TestCase < MiniTest::Unit::TestCase

  def mu_pp obj
    s = ''
    s = PP.pp obj, s
    s.chomp
  end

  def setup
    @MS  = Marshal::Structure
    @MSP = Marshal::Structure::Parser
    @MST = Marshal::Structure::Tokenizer
  end

end


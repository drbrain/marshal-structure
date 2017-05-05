require 'minitest/autorun'
require 'marshal/structure'
require 'ben_string'
require 'openssl'
require 'pp'

# :stopdoc:

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

# :startdoc:

##
# A TestCase for writing tests for Marshal::Structure and alternative parsers
# of Marshal streams.

class Marshal::Structure::TestCase < Minitest::Test

  ##
  # A Marshal stream with (almost) every type in it.  The notable absence is
  # of a Data type.

  EVERYTHING =
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

  ##
  # Pretty-print minitest diff output

  def mu_pp obj # :nodoc:
    s = ''
    s = PP.pp obj, s
    s.chomp
  end

  ##
  # Creates the following convenience namespace instance variables:
  #
  # @MS:: Marshal::Structure
  # @MSP:: Marshal::Structure::Tokenizer
  # @MST:: Marshal::Structure::Parser

  def setup
    @MS  = Marshal::Structure
    @MSP = Marshal::Structure::Parser
    @MST = Marshal::Structure::Tokenizer
  end

end


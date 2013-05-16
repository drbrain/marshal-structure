##
# Marshal::Structure dumps a nested Array describing the structure of a
# Marshal stream.
#
# Marshal format 4.8 is supported.

class Marshal::Structure

  ##
  # Generic error class for Marshal::Structure

  class Error < RuntimeError
  end

  ##
  # Raised when the Marshal stream is at the end

  class EndOfMarshal < Error

    ##
    # Number of bytes of Marshal stream consumed
    
    attr_reader :consumed

    ##
    # Requested number of bytes that was not fulfillable

    attr_reader :requested

    ##
    # Creates a new EndOfMarshal exception.  Marshal::Structure previously
    # read +consumed+ bytes and was unable to fulfill the request for
    # +requested+ additional bytes.

    def initialize consumed, requested
      @consumed = consumed
      @requested = requested

      super "consumed #{consumed} bytes, requested #{requested} more"
    end
  end

  ##
  # Version of Marshal::Structure you are using

  VERSION = '1.1.1'

  ##
  # Supported major Marshal version

  MAJOR_VERSION = 4

  ##
  # Supported minor Marshal version

  MINOR_VERSION = 8

  ##
  # Objects found in the Marshal stream.  Since objects aren't constructed the
  # actual object won't be present in this list.

  attr_reader :objects

  ##
  # Symbols found in the Marshal stream

  attr_reader :symbols

  ##
  # Returns the structure of the Marshaled object +obj+ as nested Arrays.
  #
  # For +true+, +false+ and +nil+ the symbol +:true+, +:false+, +:nil+ is
  # returned, respectively.
  #
  # For Fixnum the value is returned.
  #
  # For other objects the first item is the reference for future occurrences
  # of the object and the remaining items describe the object.
  #
  # Symbols have a separate reference table from all other objects.

  def self.load obj
    if obj.respond_to? :to_str then
      data = obj.to_s
    elsif obj.respond_to? :read then
      data = obj.read
      if data.empty? then
        raise EOFError, "end of file reached"
      end
    elsif obj.respond_to? :getc then # FIXME - don't read all of it upfront
      data = ''

      while c = obj.getc do
        data << c.chr
      end
    else
      raise TypeError, "instance of IO needed"
    end

    major = data[0].ord
    minor = data[1].ord

    if major != MAJOR_VERSION or minor > MINOR_VERSION then
      raise TypeError, "incompatible marshal file format (can't be read)\n\tformat version #{MAJOR_VERSION}.#{MINOR_VERSION} required; #{major}.#{minor} given"
    end

    new(data).parse
  end

  ##
  # Dumps the structure of each item in +argv+.  If +argv+ is empty standard
  # input is dumped.

  def self.run argv = ARGV
    require 'pp'

    if argv.empty? then
      pp load $stdin
    else
      argv.each do |file|
        open file, 'rb' do |io|
          pp load io
        end
      end
    end
  end

  ##
  # Prepares processing of +stream+

  def initialize stream
    @tokenizer = Marshal::Structure::Tokenizer.new stream
  end

  def parse
    parser = Marshal::Structure::Parser.new @tokenizer

    parser.parse
  end

end

require 'marshal/structure/parser'
require 'marshal/structure/tokenizer'


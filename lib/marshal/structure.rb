##
# Marshal::Structure dumps a nested Array describing the structure of a
# Marshal stream.  Marshal format 4.8 (Ruby 1.8 through 2.x) is supported.
#
# Examples:
#
# To dump the structure of a Marshal stream:
# 
#   ruby -rpp -rmarshal/structure \
#     -e 'pp Marshal::Structure.load Marshal.dump "hello"'
# 
# Fancier usage:
# 
#   require 'pp'
#   require 'marshal/structure'
# 
#   ms = Marshal::Structure.new Marshal.dump %w[hello world]
# 
#   # print the stream structure
#   pp ms.structure
# 
#   # show how many allocations are required to load the stream
#   p ms.count_allocations


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

  VERSION = '2.0'

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
      raise EOFError, "end of file reached" if data.empty?
    elsif obj.respond_to? :getc then # FIXME - don't read all of it upfront
      data = ''

      while c = obj.getc do
        data << c.chr
      end
    else
      raise TypeError, "instance of IO needed"
    end

    new(data).structure
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

  ##
  # Counts allocations required to load the Marshal stream.  See
  # Marshal::Structure::AllocationsCounter for a description of how counting
  # is performed.

  def count_allocations
    counter = Marshal::Structure::AllocationCounter.new token_stream

    counter.count
  end

  ##
  # Returns the structure of the Marshal stream.

  def structure
    parser = Marshal::Structure::Parser.new token_stream

    parser.parse
  end

  ##
  # Returns an Enumerator for the tokens in the Marshal stream.

  def token_stream
    @tokenizer.tokens
  end

end

require 'marshal/structure/allocation_counter'
require 'marshal/structure/parser'
require 'marshal/structure/tokenizer'


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

    new(data).construct
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
    @objects = []
    @symbols = []

    @tokenizer = Marshal::Structure::Tokenizer.new stream
  end

  ##
  # Adds +obj+ to the objects list

  def add_object obj
    return if
      [NilClass, TrueClass, FalseClass, Symbol, Fixnum].any? { |c| c === obj }

    index = @objects.size
    @objects << obj
    index
  end

  ##
  # Adds +symbol+ to the symbols list

  def add_symlink symbol
    index = @symbols.size
    @symbols << symbol
    index
  end

  ##
  # Creates the structure for the remaining stream.

  def construct
    token = @tokenizer.next_token

    return token if [:nil, :true, :false].include? token

    obj = [token]

    rest = 
      case token
      when :array                       then construct_array
      when :bignum                      then construct_bignum
      when :class, :module              then construct_class
      when :data                        then construct_data
      when :extended                    then construct_extended
      when :fixnum, :link, :symbol_link then [@tokenizer.next_token]
      when :float                       then construct_float
      when :hash                        then construct_hash
      when :hash_default                then construct_hash_def
      when :object                      then construct_object
      when :regexp                      then construct_regexp
      when :string                      then construct_string
      when :struct                      then construct_struct
      when :symbol                      then construct_symbol
      when :user_class                  then construct_extended
      when :user_defined                then construct_user_defined
      when :user_marshal                then construct_user_marshal
      when :instance_variables          then
        [construct].concat construct_instance_variables
      when :module_old                  then
        obj[0] = :module
        construct_class
      else
        raise Error, "bug: unknown token #{token.inspect}"
      end

    obj.concat rest
  rescue EndOfMarshal
    raise ArgumentError, 'marshal data too short'
  end

  ##
  # Creates the body of an +:array+ object

  def construct_array
    ref = store_unique_object Object.allocate

    obj = [ref]

    items = @tokenizer.next_token

    obj << items

    items.times do
      obj << construct
    end

    obj
  end

  ##
  # Creates the body of a +:bignum+ object

  def construct_bignum
    result = @tokenizer.next_token

    ref = store_unique_object Object.allocate

    [ref, result]
  end

  ##
  # Creates the body of a +:class+ object

  def construct_class
    ref = store_unique_object Object.allocate

    [ref, @tokenizer.next_token]
  end

  ##
  # Creates the body of a wrapped C pointer object

  def construct_data
    ref = store_unique_object Object.allocate

    [ref, get_symbol, construct]
  end

  ##
  # Creates the body of an extended object

  def construct_extended
    [get_symbol, construct]
  end

  ##
  # Creates the body of a +:float+ object

  def construct_float
    float = @tokenizer.next_token

    ref = store_unique_object Object.allocate

    [ref, float]
  end

  ##
  # Creates the body of a +:hash+ object

  def construct_hash
    ref = store_unique_object Object.allocate

    obj = [ref]

    pairs = @tokenizer.next_token
    obj << pairs

    pairs.times do
      obj << construct
      obj << construct
    end

    obj
  end

  ##
  # Creates the body of a +:hash_def+ object

  def construct_hash_def
    ref, hash = construct_hash

    [ref, hash, construct]
  end

  ##
  # Instance variables contain an object followed by a count of instance
  # variables and their contents

  def construct_instance_variables
    instance_variables = []

    pairs = @tokenizer.next_token
    instance_variables << pairs

    pairs.times do
      instance_variables << get_symbol
      instance_variables << construct
    end

    instance_variables
  end

  ##
  # Creates an Object

  def construct_object
    ref = store_unique_object Object.allocate

    [ref, get_symbol, construct_instance_variables]
  end

  ##
  # Creates a Regexp

  def construct_regexp
    ref = store_unique_object Object.allocate

    [ref, @tokenizer.next_token, @tokenizer.next_token]
  end

  ##
  # Creates a String

  def construct_string
    ref = store_unique_object Object.allocate

    [ref, @tokenizer.next_token]
  end

  ##
  # Creates a Struct

  def construct_struct
    obj_ref = store_unique_object Object.allocate

    obj = [obj_ref, get_symbol]

    members = @tokenizer.next_token
    obj << members

    members.times do
      obj << get_symbol
      obj << construct
    end

    obj
  end

  ##
  # Creates a Symbol

  def construct_symbol
    sym = @tokenizer.next_token

    ref = store_unique_object sym.to_sym

    [ref, sym]
  end

  ##
  # Creates an object saved by _dump

  def construct_user_defined
    name = get_symbol

    data = @tokenizer.next_token

    ref = store_unique_object Object.allocate

    [ref, name, data]
  end

  ##
  # Creates an object saved by marshal_dump

  def construct_user_marshal
    name = get_symbol

    obj = Object.allocate

    obj_ref = store_unique_object obj

    [obj_ref, name, construct]
  end

  ##
  # Constructs a Symbol from a TYPE_SYMBOL or TYPE_SYMLINK

  def get_symbol
    token = @tokenizer.next_token

    case token
    when :symbol then
      [:symbol, *construct_symbol]
    when :symbol_link then
      [:symbol_link, @tokenizer.next_token]
    else
      raise ArgumentError, "expected SYMBOL or SYMLINK, got #{token.inspect}"
    end
  end

  ##
  # Stores a reference to +obj+

  def store_unique_object obj
    if Symbol === obj then
      add_symlink obj
    else
      add_object obj
    end
  end

end

require 'marshal/structure/tokenizer'


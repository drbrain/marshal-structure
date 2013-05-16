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
  # nil type prefix

  TYPE_NIL = '0'

  ##
  # true type prefix

  TYPE_TRUE = 'T'

  ##
  # false type prefix

  TYPE_FALSE = 'F'

  ##
  # Fixnum type prefix

  TYPE_FIXNUM = 'i'

  ##
  # An object that has been extended with a module

  TYPE_EXTENDED = 'e'

  ##
  # A subclass of a built-in type

  TYPE_UCLASS = 'C'

  ##
  # A ruby Object

  TYPE_OBJECT = 'o'

  ##
  # A wrapped C pointer

  TYPE_DATA = 'd'

  ##
  # An object saved with _dump

  TYPE_USERDEF = 'u'

  ##
  # An object saved with marshal_dump

  TYPE_USRMARSHAL = 'U'

  ##
  # A Float

  TYPE_FLOAT = 'f'

  ##
  # A Bignum

  TYPE_BIGNUM = 'l'

  ##
  # A String

  TYPE_STRING = '"'

  ##
  # A Regexp

  TYPE_REGEXP = '/'

  ##
  # An Array

  TYPE_ARRAY = '['

  ##
  # A Hash

  TYPE_HASH = '{'

  ##
  # A Hash with a default value (not proc)

  TYPE_HASH_DEF = '}'

  ##
  # A Struct

  TYPE_STRUCT = 'S'

  ##
  # An old-style Module (reference, not content)
  #
  # I'm not sure what makes this old.  The byte stream is identical to
  # TYPE_MODULE

  TYPE_MODULE_OLD = 'M'

  ##
  # A class (reference, not content)

  TYPE_CLASS = 'c'

  ##
  # A module (reference, not content)

  TYPE_MODULE = 'm'

  ##
  # A Symbol

  TYPE_SYMBOL = ':'

  ##
  # A reference to a previously Symbol

  TYPE_SYMLINK = ';'

  ##
  # Instance variables for a following object

  TYPE_IVAR = 'I'

  ##
  # A reference to a previously-stored Object

  TYPE_LINK = '@'

  TYPE_MAP = Hash.new do |_, type| # :nodoc:
    raise Error, "unknown type #{type.inspect}"
  end

  TYPE_MAP[TYPE_ARRAY]      = :array
  TYPE_MAP[TYPE_BIGNUM]     = :bignum
  TYPE_MAP[TYPE_CLASS]      = :class
  TYPE_MAP[TYPE_DATA]       = :data
  TYPE_MAP[TYPE_EXTENDED]   = :extended
  TYPE_MAP[TYPE_FALSE]      = :false
  TYPE_MAP[TYPE_FIXNUM]     = :fixnum
  TYPE_MAP[TYPE_FLOAT]      = :float
  TYPE_MAP[TYPE_HASH]       = :hash
  TYPE_MAP[TYPE_HASH_DEF]   = :hash_default
  TYPE_MAP[TYPE_IVAR]       = :instance_variables
  TYPE_MAP[TYPE_LINK]       = :link
  TYPE_MAP[TYPE_MODULE]     = :module
  TYPE_MAP[TYPE_MODULE_OLD] = :module_old
  TYPE_MAP[TYPE_NIL]        = :nil
  TYPE_MAP[TYPE_OBJECT]     = :object
  TYPE_MAP[TYPE_REGEXP]     = :regexp
  TYPE_MAP[TYPE_STRING]     = :string
  TYPE_MAP[TYPE_STRUCT]     = :struct
  TYPE_MAP[TYPE_SYMBOL]     = :symbol
  TYPE_MAP[TYPE_SYMLINK]    = :symbol_link
  TYPE_MAP[TYPE_TRUE]       = :true
  TYPE_MAP[TYPE_UCLASS]     = :user_class
  TYPE_MAP[TYPE_USERDEF]    = :user_defined
  TYPE_MAP[TYPE_USRMARSHAL] = :user_marshal

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
      data << c while (c = obj.getc.chr)
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

    @byte_array = stream.bytes.to_a
    @consumed   = 2
    @state      = [:any]
    @stream     = stream
    @stream.force_encoding Encoding::BINARY
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
    token = next_token

    return token if [:nil, :true, :false].include? token

    obj = [token]

    case token
    when :array then
      obj.concat construct_array
    when :bignum then
      obj.concat construct_bignum
    when :class, :module then
      obj.concat construct_class
    when :data then
      obj.concat construct_data
    when :extended then
      obj.concat construct_extended
    when :fixnum then
      obj << next_token
    when :float then
      obj.concat construct_float
    when :hash then
      obj.concat construct_hash
    when :hash_default then
      obj.concat construct_hash_def
    when :instance_variables then
      obj << construct
      obj.concat construct_instance_variables
    when :link then
      obj << next_token
    when :module_old then
      obj[0] = :module
      obj.concat construct_class
    when :object then
      obj.concat construct_object
    when :regexp then
      obj.concat construct_regexp
    when :string then
      obj.concat construct_string
    when :struct then
      obj.concat construct_struct
    when :symbol then
      obj.concat construct_symbol
    when :symbol_link then
      obj << next_token
    when :user_class then
      obj.concat construct_extended
    when :user_defined then
      obj.concat construct_user_defined
    when :user_marshal then
      obj.concat construct_user_marshal
    else
      raise Error, "bug: unknown token #{token.inspect}"
    end
  rescue EndOfMarshal
    raise ArgumentError, 'marshal data too short'
  end

  ##
  # Creates the body of an +:array+ object

  def construct_array
    ref = store_unique_object Object.allocate

    obj = [ref]

    items = next_token

    obj << items

    items.times do
      obj << construct
    end

    obj
  end

  ##
  # Creates the body of a +:bignum+ object

  def construct_bignum
    result = next_token

    ref = store_unique_object Object.allocate

    [ref, result]
  end

  ##
  # Creates the body of a +:class+ object

  def construct_class
    ref = store_unique_object Object.allocate

    [ref, next_token]
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
    float = next_token

    ref = store_unique_object Object.allocate

    [ref, float]
  end

  ##
  # Creates the body of a +:hash+ object

  def construct_hash
    ref = store_unique_object Object.allocate

    obj = [ref]

    pairs = next_token
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

    pairs = next_token
    instance_variables << pairs

    pairs.times do
      instance_variables << get_symbol
      instance_variables << construct
    end

    instance_variables
  end

  ##
  # Decodes a stored Fixnum

  def construct_integer
    c = consume_byte

    return 0 if c == 0

    # convert to signed integer
    c = (c ^ 0x80) - 0x80

    if c > 0 then
      return c - 5 if 4 < c

      x = 0

      c.times do |i|
        x |= consume_byte << (8 * i)
      end
      
      x
    else
      return c + 5 if c < -4

      x = -1

      (-c).times do |i|
        factor = 8 * i
        x &= ~(0xff << factor)
        x |= consume_byte << factor
      end

      x
    end
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

    [ref, next_token, next_token]
  end

  ##
  # Creates a String

  def construct_string
    ref = store_unique_object Object.allocate

    [ref, next_token]
  end

  ##
  # Creates a Struct

  def construct_struct
    symbols = []
    values = []

    obj_ref = store_unique_object Object.allocate

    obj = [obj_ref, get_symbol]

    members = next_token
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
    sym = next_token

    ref = store_unique_object sym.to_sym

    [ref, sym]
  end

  ##
  # Creates an object saved by _dump

  def construct_user_defined
    name = get_symbol

    data = next_token

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
  # Consumes +bytes+ from the marshal stream

  def consume bytes
    raise EndOfMarshal.new(@consumed, bytes) if
      @consumed + bytes > @stream.size

    data = @stream[@consumed, bytes]
    @consumed += bytes
    data
  end

  ##
  # Consumes +count+ bytes from the marshal stream as an Array of bytes

  def consume_bytes count
    consume(count).bytes.to_a
  end

  ##
  # Consumes one byte from the marshal stream

  def consume_byte
    raise EndOfMarshal.new(@consumed, 1) if @consumed >= @byte_array.size

    data = @byte_array[@consumed]
    @consumed += 1

    data
  end

  ##
  # Consumes one byte from the marshal stream and returns a character

  def consume_character
    consume_byte.chr
  end

  ##
  # Consumes a sequence of bytes from the marshal stream based on the next
  # integer

  def get_byte_sequence
    size = construct_integer
    consume size
  end

  ##
  # Constructs a Symbol from a TYPE_SYMBOL or TYPE_SYMLINK

  def get_symbol
    token = next_token

    case token
    when :symbol then
      [:symbol, *construct_symbol]
    when :symbol_link then
      [:symbol_link, next_token]
    else
      raise ArgumentError, "expected SYMBOL or SYMLINK, got #{token.inspect}"
    end
  end

  ##
  # Attempts to retrieve the next token from the stream.  You may need to call
  # next_token twice to receive a token as the current token may be
  # incomplete.

  def next_token # :nodoc:
    current_state = @state.pop

    case current_state
    when :any                         then tokenize_any
    when :array                       then tokenize_array
    when :bignum                      then tokenize_bignum
    when :byte                        then consume_byte
    when :bytes,
         :class, :module, :module_old,
         :float, :string, :symbol     then get_byte_sequence
    when :data                        then tokenize_data
    when :extended                    then tokenize_extended
    when :fixnum, :link, :symbol_link then construct_integer
    when :hash, :pairs                then tokenize_pairs
    when :hash_default                then tokenize_hash_default
    when :instance_variables          then tokenize_instance_variables
    when :object                      then tokenize_object
    when :regexp                      then tokenize_regexp
    when :struct                      then tokenize_struct
    when :sym                         then tokenize_sym
    when :user_class                  then tokenize_user_class
    when :user_defined                then tokenize_user_defined
    when :user_marshal                then tokenize_user_marshal
    else
      raise Error, "bug: unknown state #{current_state.inspect}"
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

  ##
  # Returns an Enumerator that will tokenize the Marshal stream.

  def tokens
    Enumerator.new do |yielder|
      until @state.empty? do
        token = next_token

        yielder << token if token
      end
    end
  end

  def tokenize_any # :nodoc:
    item_type = TYPE_MAP[consume_character]

    @state.push item_type unless [:nil, :true, :false].include? item_type

    item_type
  end

  def tokenize_array # :nodoc:
    size = construct_integer

    @state.concat Array.new(size, :any)

    size
  end

  def tokenize_bignum # :nodoc:
    sign = consume_byte == 45 ? -1 : 1
    size = construct_integer * 2

    result = 0

    data = consume_bytes size

    data.each_with_index do |data, exp|
      result += (data * 2**(exp*8))
    end

    sign * result
  end

  def tokenize_data # :nodoc:
    @state.push :any
    @state.push :sym

    next_token
  end

  alias tokenize_extended tokenize_data # :nodoc:

  def tokenize_hash_default # :nodoc:
    size = construct_integer

    @state.push :any
    @state.push size * 2 if size > 0

    size
  end

  def tokenize_instance_variables # :nodoc:
    @state.push :pairs
    @state.push :any

    next_token
  end

  ##
  # For multipart objects like arrays and hashes a count of items is pushed
  # onto the stack.  This method re-pushes an :any onto the stack until the
  # correct number of tokens have been created from the stream.

  def tokenize_next_any current_state # :nodoc:
    next_state = current_state - 1
    @state.push next_state if current_state > 0
    @state.push :any

    next_token
  end

  def tokenize_object # :nodoc:
    @state.push :fixnum
    @state.push :sym

    next_token
  end

  def tokenize_pairs # :nodoc:
    size = construct_integer

    @state.concat Array.new(size * 2, :any)

    size
  end

  def tokenize_regexp # :nodoc:
    @state.push :byte

    get_byte_sequence
  end

  def tokenize_struct # :nodoc:
    @state.push :pairs
    @state.push :sym

    next_token
  end

  def tokenize_sym # :nodoc:
    item_type = TYPE_MAP[consume_character]

    raise Error, "expected symbol type, got #{item_type.inspect}" unless
      [:symbol, :symbol_link].include? item_type

    @state.push item_type

    item_type
  end

  alias tokenize_user_class tokenize_data # :nodoc:

  def tokenize_user_defined # :nodoc:
    @state.push :bytes
    @state.push :sym

    next_token
  end

  alias tokenize_user_marshal tokenize_data # :nodoc:

end


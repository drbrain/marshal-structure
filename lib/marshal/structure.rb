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

    @stream = stream
    @byte_array = stream.bytes.to_a
    @consumed = 2
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
    type = consume_character

    case type
    when TYPE_NIL then
      :nil
    when TYPE_TRUE then
      :true
    when TYPE_FALSE then
      :false

    when TYPE_ARRAY then
      [:array, *construct_array]
    when TYPE_BIGNUM then
      [:bignum, *construct_bignum]
    when TYPE_CLASS then
      ref = store_unique_object Object.allocate

      [:class, ref, get_byte_sequence]
    when TYPE_DATA then
      [:data, *construct_data]
    when TYPE_EXTENDED then
      [:extended, get_symbol, construct]
    when TYPE_FIXNUM then
      [:fixnum, construct_integer]
    when TYPE_FLOAT then
      [:float, *construct_float]
    when TYPE_HASH then
      [:hash, *construct_hash]
    when TYPE_HASH_DEF then
      [:hash_default, *construct_hash_def]
    when TYPE_IVAR then
      [:instance_variables, construct, *construct_instance_variables]
    when TYPE_LINK then
      [:link, construct_integer]
    when TYPE_MODULE, TYPE_MODULE_OLD then
      ref = store_unique_object Object.allocate

      [:module, ref, get_byte_sequence]
    when TYPE_OBJECT then
      [:object, *construct_object]
    when TYPE_REGEXP then
      [:regexp, *construct_regexp]
    when TYPE_STRING then
      [:string, *construct_string]
    when TYPE_STRUCT then
      [:struct, *construct_struct]
    when TYPE_SYMBOL then
      [:symbol, *construct_symbol]
    when TYPE_SYMLINK then
      [:symbol_link, construct_integer]
    when TYPE_USERDEF then
      [:user_defined, *construct_user_defined]
    when TYPE_USRMARSHAL then
      [:user_marshal, *construct_user_marshal]
    when TYPE_UCLASS then
      name = get_symbol

      [:user_class, name, construct]
    else
      raise ArgumentError, "load error, unknown type #{type}"
    end
  rescue EndOfMarshal
    raise ArgumentError, 'marshal data too short'
  end

  ##
  # Creates the body of an +:array+ object

  def construct_array
    ref = store_unique_object Object.allocate

    obj = [ref]

    items = construct_integer

    obj << items

    items.times do
      obj << construct
    end

    obj
  end

  ##
  # Creates the body of a +:bignum+ object

  def construct_bignum
    sign = consume_byte == ?- ? -1 : 1
    size = construct_integer * 2

    result = 0

    data = consume_bytes size

    data.each_with_index do |data, exp|
      result += (data * 2**(exp*8))
    end

    ref = store_unique_object Object.allocate

    [ref, sign, size, result]
  end

  ##
  # Creates the body of a wrapped C pointer object

  def construct_data
    ref = store_unique_object Object.allocate

    [ref, get_symbol, construct]
  end

  ##
  # Creates the body of a +:float+ object

  def construct_float
    float = get_byte_sequence

    ref = store_unique_object Object.allocate

    [ref, float]
  end

  ##
  # Creates the body of a +:hash+ object

  def construct_hash
    ref = store_unique_object Object.allocate

    obj = [ref]

    pairs = construct_integer
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

    pairs = construct_integer
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

    # The format appears to be a simple integer compression format
    #
    # The 0-123 cases are easy, and use one byte
    # We've read c as unsigned char in a way, but we need to honor
    # the sign bit. We do that by simply comparing with the +128 values
    return 0 if c == 0
    return c - 5 if 4 < c and c < 128

    # negative, but checked known it's instead in 2's compliment
    return c - 251 if 252 > c and c > 127

    # otherwise c (now in the 1 to 4 range) indicates how many
    # bytes to read to construct the value.
    #
    # Because we're operating on a small number of possible values,
    # it's cleaner to just unroll the calculate of each

    case c
    when 1
      consume_byte
    when 2
      consume_byte | (consume_byte << 8)
    when 3
      consume_byte | (consume_byte << 8) | (consume_byte << 16)
    when 4
      consume_byte | (consume_byte << 8) | (consume_byte << 16) |
                     (consume_byte << 24)

    when 255 # -1
      consume_byte - 256
    when 254 # -2
      (consume_byte | (consume_byte << 8)) - 65536
    when 253 # -3
      (consume_byte |
       (consume_byte << 8) |
       (consume_byte << 16)) - 16777216 # 2 ** 24
    when 252 # -4
      (consume_byte |
       (consume_byte << 8) |
       (consume_byte << 16) |
       (consume_byte << 24)) - 4294967296
    else
      raise "Invalid integer size: #{c}"
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
    ref =store_unique_object Object.allocate

    [ref, get_byte_sequence, consume_byte]
  end

  ##
  # Creates a String

  def construct_string
    ref = store_unique_object Object.allocate

    [ref, get_byte_sequence]
  end

  ##
  # Creates a Struct

  def construct_struct
    symbols = []
    values = []

    obj_ref = store_unique_object Object.allocate

    obj = [obj_ref, get_symbol]

    members = construct_integer
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
    sym = get_byte_sequence

    ref = store_unique_object sym.to_sym

    [ref, sym]
  end

  ##
  # Creates an object saved by _dump

  def construct_user_defined
    name = get_symbol

    data = get_byte_sequence

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
    raise ArgumentError, "marshal data too short" if @consumed > @stream.size
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
    raise EndOfMarshal if @consumed >= @byte_array.size

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
    type = consume_character

    case type
    when TYPE_SYMBOL then
      [:symbol, *construct_symbol]
    when TYPE_SYMLINK then
      num = construct_integer
      [:symbol_link, num]
    else
      raise ArgumentError, "expected TYPE_SYMBOL or TYPE_SYMLINK, got #{type.inspect}"
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


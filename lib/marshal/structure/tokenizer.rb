class Marshal::Structure::Tokenizer

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
    raise Marshal::Structure::Error, "unknown type #{type.inspect}"
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
  # Creates a Tokenizer for a Marshal stream in String +stream+.

  def initialize stream
    @byte_array = stream.bytes.to_a
    @consumed   = 2
    @state      = [:any]
    @stream     = stream
    @stream.force_encoding Encoding::BINARY
  end

  ##
  # Consumes one byte from the marshal stream

  def byte
    raise Marshal::Structure::EndOfMarshal.new(@consumed, 1) if
      @consumed >= @byte_array.size

    data = @byte_array[@consumed]
    @consumed += 1

    data
  end

  ##
  # Consumes +count+ bytes from the marshal stream as an Array of bytes

  def byte_array count
    bytes(count).bytes.to_a
  end

  ##
  # Consumes a sequence of bytes from the marshal stream based on the next
  # integer

  def byte_sequence
    size = long
    bytes size
  end

  ##
  # Consumes +count+ from the marshal stream

  def bytes count
    raise Marshal::Structure::EndOfMarshal.new(@consumed, count) if
      @consumed + count > @stream.size

    data = @stream[@consumed, count]
    @consumed += count
    data
  end

  ##
  # Consumes one byte from the marshal stream and returns a character

  def character
    byte.chr
  end

  ##
  # Checks if the stream starts with a compatible marshal version

  def check_version
    major = @stream[0].ord
    minor = @stream[1].ord

    return if major == MAJOR_VERSION and minor <= MINOR_VERSION

    raise TypeError, "incompatible marshal file format (can't be read)\n\tformat version #{MAJOR_VERSION}.#{MINOR_VERSION} required; #{major}.#{minor} given"
  end

  ##
  # Decodes a stored C long

  def long
    c = byte

    return 0 if c == 0

    # convert to signed integer
    c = (c ^ 0x80) - 0x80

    if c > 0 then
      return c - 5 if 4 < c

      x = 0

      c.times do |i|
        x |= byte << (8 * i)
      end
      
      x
    else
      return c + 5 if c < -4

      x = -1

      (-c).times do |i|
        factor = 8 * i
        x &= ~(0xff << factor)
        x |= byte << factor
      end

      x
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
    when :byte                        then byte
    when :bytes,
         :class, :module, :module_old,
         :float, :string, :symbol     then byte_sequence
    when :data                        then tokenize_data
    when :extended                    then tokenize_extended
    when :fixnum, :link, :symbol_link then long
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
      raise Marshal::Structure::Error,
            "bug: unknown state #{current_state.inspect}"
    end
  end

  ##
  # Returns an Enumerator that will tokenize the Marshal stream.

  def tokens
    check_version

    Enumerator.new do |yielder|
      until @state.empty? do
        token = next_token

        yielder << token if token
      end
    end
  end

  def tokenize_any # :nodoc:
    item_type = TYPE_MAP[character]

    @state.push item_type unless [:nil, :true, :false].include? item_type

    item_type
  end

  def tokenize_array # :nodoc:
    size = long

    @state.concat Array.new(size, :any)

    size
  end

  def tokenize_bignum # :nodoc:
    sign = byte == 45 ? -1 : 1
    size = long * 2

    result = 0

    bytes = byte_array size

    bytes.each_with_index do |byte, exp|
      result += (byte * 2**(exp*8))
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
    size = long

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
    size = long

    @state.concat Array.new(size * 2, :any)

    size
  end

  def tokenize_regexp # :nodoc:
    @state.push :byte

    byte_sequence
  end

  def tokenize_struct # :nodoc:
    @state.push :pairs
    @state.push :sym

    next_token
  end

  def tokenize_sym # :nodoc:
    item_type = TYPE_MAP[character]

    raise Marshal::Structure::Error,
          "expected symbol type, got #{item_type.inspect}" unless
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


##
# Parses a tokenized Marshal stream into a structure that resembles how the
# stream would be loaded.
#
# Marshal can contain references to previous objects.  These references are
# included in the structure following referenceable items.  For example, a
# recursive array:
#
#    a = []
#    a << self
#
# Has the following Marshal stream:
#
#   "\x04\x08[\x06@\x00" # @\x00 is a link to the first Object in the stream
#
# And has the following Marshal structure:
#
#   [:array, 0, 1,
#     [:link, 0]]
#
# The first item after +:array+, the +0+ is the object's stream ID.  The
# +:link+ references this ID.

class Marshal::Structure::Parser

  ##
  # Creates a new Parser using a token stream Enumerator +tokens+.

  def initialize tokens
    @tokens = tokens
    @objects = -1
    @symbols = -1
  end

  ##
  # Creates a new object reference

  def object_ref
    @objects += 1
  end

  ##
  # Creates the structure for the remaining stream.

  def parse
    token = @tokens.next

    return token if [:nil, :true, :false].include? token

    obj = [token]

    rest =
      case token
      when :array                       then parse_array
      when :bignum                      then parse_bignum
      when :class, :module              then parse_class
      when :data                        then parse_data
      when :extended                    then parse_extended
      when :fixnum, :link, :symbol_link then [@tokens.next]
      when :float                       then parse_float
      when :hash                        then parse_hash
      when :hash_default                then parse_hash_def
      when :object                      then parse_object
      when :regexp                      then parse_regexp
      when :string                      then parse_string
      when :struct                      then parse_struct
      when :symbol                      then parse_symbol
      when :user_class                  then parse_extended
      when :user_defined                then parse_user_defined
      when :user_marshal                then parse_user_marshal
      when :instance_variables          then
        [parse].concat parse_instance_variables
      when :module_old                  then
        obj[0] = :module
        parse_class
      else
        raise Marshal::Structure::Error, "bug: unknown token #{token.inspect}"
      end

    obj.concat rest
  rescue Marshal::Structure::EndOfMarshal
    raise ArgumentError, 'marshal data too short'
  end

  ##
  # Creates the body of an +:array+ object

  def parse_array
    obj = [object_ref]

    items = @tokens.next

    obj << items

    items.times do
      obj << parse
    end

    obj
  end

  ##
  # Creates the body of a +:bignum+ object

  def parse_bignum
    result = @tokens.next

    [object_ref, result]
  end

  ##
  # Creates the body of a +:class+ object

  def parse_class
    [object_ref, @tokens.next]
  end

  ##
  # Creates the body of a wrapped C pointer object

  def parse_data
    [object_ref, get_symbol, parse]
  end

  ##
  # Creates the body of an extended object

  def parse_extended
    [get_symbol, parse]
  end

  ##
  # Creates the body of a +:float+ object

  def parse_float
    float = @tokens.next

    [object_ref, float]
  end

  ##
  # Creates the body of a +:hash+ object

  def parse_hash
    obj = [object_ref]

    pairs = @tokens.next
    obj << pairs

    pairs.times do
      obj << parse
      obj << parse
    end

    obj
  end

  ##
  # Creates the body of a +:hash_def+ object

  def parse_hash_def
    [*parse_hash, parse]
  end

  ##
  # Instance variables contain an object followed by a count of instance
  # variables and their contents

  def parse_instance_variables
    instance_variables = []

    pairs = @tokens.next
    instance_variables << pairs

    pairs.times do
      instance_variables << get_symbol
      instance_variables << parse
    end

    instance_variables
  end

  ##
  # Creates an Object

  def parse_object
    [object_ref, get_symbol, parse_instance_variables]
  end

  ##
  # Creates a Regexp

  def parse_regexp
    [object_ref, @tokens.next, @tokens.next]
  end

  ##
  # Creates a String

  def parse_string
    [object_ref, @tokens.next]
  end

  ##
  # Creates a Struct

  def parse_struct
    obj = [object_ref, get_symbol]

    members = @tokens.next
    obj << members

    members.times do
      obj << get_symbol
      obj << parse
    end

    obj
  end

  ##
  # Creates a Symbol

  def parse_symbol
    sym = @tokens.next

    [symbol_ref, sym]
  end

  ##
  # Creates an object saved by _dump

  def parse_user_defined
    name = get_symbol

    data = @tokens.next

    [object_ref, name, data]
  end

  ##
  # Creates an object saved by marshal_dump

  def parse_user_marshal
    name = get_symbol

    [object_ref, name, parse]
  end

  ##
  # Creates a new symbol reference

  def symbol_ref
    @symbols += 1
  end

  ##
  # Constructs a Symbol from the token stream

  def get_symbol
    token = @tokens.next

    case token
    when :symbol then
      [:symbol, *parse_symbol]
    when :symbol_link then
      [:symbol_link, @tokens.next]
    else
      raise ArgumentError, "expected SYMBOL or SYMLINK, got #{token.inspect}"
    end
  end

end


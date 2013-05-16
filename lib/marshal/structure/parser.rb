class Marshal::Structure::Parser

  def initialize tokenizer
    @tokenizer = tokenizer

    @objects = []
    @symbols = []
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

  def parse
    token = @tokenizer.next_token

    return token if [:nil, :true, :false].include? token

    obj = [token]

    rest = 
      case token
      when :array                       then parse_array
      when :bignum                      then parse_bignum
      when :class, :module              then parse_class
      when :data                        then parse_data
      when :extended                    then parse_extended
      when :fixnum, :link, :symbol_link then [@tokenizer.next_token]
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
        raise Error, "bug: unknown token #{token.inspect}"
      end

    obj.concat rest
  rescue Marshal::Structure::EndOfMarshal
    raise ArgumentError, 'marshal data too short'
  end

  ##
  # Creates the body of an +:array+ object

  def parse_array
    ref = store_unique_object Object.allocate

    obj = [ref]

    items = @tokenizer.next_token

    obj << items

    items.times do
      obj << parse
    end

    obj
  end

  ##
  # Creates the body of a +:bignum+ object

  def parse_bignum
    result = @tokenizer.next_token

    ref = store_unique_object Object.allocate

    [ref, result]
  end

  ##
  # Creates the body of a +:class+ object

  def parse_class
    ref = store_unique_object Object.allocate

    [ref, @tokenizer.next_token]
  end

  ##
  # Creates the body of a wrapped C pointer object

  def parse_data
    ref = store_unique_object Object.allocate

    [ref, get_symbol, parse]
  end

  ##
  # Creates the body of an extended object

  def parse_extended
    [get_symbol, parse]
  end

  ##
  # Creates the body of a +:float+ object

  def parse_float
    float = @tokenizer.next_token

    ref = store_unique_object Object.allocate

    [ref, float]
  end

  ##
  # Creates the body of a +:hash+ object

  def parse_hash
    ref = store_unique_object Object.allocate

    obj = [ref]

    pairs = @tokenizer.next_token
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
    ref, hash = parse_hash

    [ref, hash, parse]
  end

  ##
  # Instance variables contain an object followed by a count of instance
  # variables and their contents

  def parse_instance_variables
    instance_variables = []

    pairs = @tokenizer.next_token
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
    ref = store_unique_object Object.allocate

    [ref, get_symbol, parse_instance_variables]
  end

  ##
  # Creates a Regexp

  def parse_regexp
    ref = store_unique_object Object.allocate

    [ref, @tokenizer.next_token, @tokenizer.next_token]
  end

  ##
  # Creates a String

  def parse_string
    ref = store_unique_object Object.allocate

    [ref, @tokenizer.next_token]
  end

  ##
  # Creates a Struct

  def parse_struct
    obj_ref = store_unique_object Object.allocate

    obj = [obj_ref, get_symbol]

    members = @tokenizer.next_token
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
    sym = @tokenizer.next_token

    ref = store_unique_object sym.to_sym

    [ref, sym]
  end

  ##
  # Creates an object saved by _dump

  def parse_user_defined
    name = get_symbol

    data = @tokenizer.next_token

    ref = store_unique_object Object.allocate

    [ref, name, data]
  end

  ##
  # Creates an object saved by marshal_dump

  def parse_user_marshal
    name = get_symbol

    obj = Object.allocate

    obj_ref = store_unique_object obj

    [obj_ref, name, parse]
  end

  ##
  # Constructs a Symbol from the token stream

  def get_symbol
    token = @tokenizer.next_token

    case token
    when :symbol then
      [:symbol, *parse_symbol]
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


##
# Counts allocations necessary to load the stream.  The number of allocations
# may be less as symbols (e.g. for object instance variables) may already
# exist.
#
# Allocation counts are determined as follows:
#
# * References to classes or modules are not counted.  They either already
#   exist or cause an ArgumentError upon load.
# * true, false, nil and Fixnum are not counted as they are all singletons.
# * Symbols count as one allocation even if they may already exist.  (Marshal
#   automatically compresses duplicate mentions of symbols and objects, so
#   they will only be counted once).
# * Other objects are counted as one allocation.

class Marshal::Structure::AllocationCounter

  ##
  # Creates a new AllocationCounter for +tokens+

  def initialize tokens
    @tokens = tokens
  end

  ##
  # Counts objects allocated from the stream.

  def count
    token = @tokens.next

    case token
    when :nil, :true, :false          then 0
    when :array                       then count_array
    when :bignum                      then count_bignum
    when :class, :module, :module_old then count_class
    when :data                        then count_data
    when :extended                    then count_extended
    when :fixnum, :link, :symbol_link then @tokens.next; 0
    when :float                       then count_float
    when :hash                        then count_hash
    when :hash_default                then count_hash_default
    when :object                      then count_object
    when :regexp                      then count_regexp
    when :string                      then count_string
    when :struct                      then count_struct
    when :symbol                      then count_symbol
    when :user_class                  then count_extended
    when :user_defined                then count_user_defined
    when :user_marshal                then count_user_marshal
    when :instance_variables          then count + count_instance_variables
    else
      raise Marshal::Structure::Error, "bug: unknown token #{token.inspect}"
    end
  rescue Marshal::Structure::EndOfMarshal
    raise ArgumentError, 'marshal data too short'
  end

  def count_array # :nodoc:
    allocations = 1

    @tokens.next.times do
      allocations += count
    end

    allocations
  end

  def count_bignum # :nodoc:
    @tokens.next

    1
  end

  def count_class # :nodoc:
    @tokens.next

    0
  end

  def count_data # :nodoc:
    get_symbol

    1 + count
  end

  def count_extended # :nodoc:
    get_symbol

    count
  end

  alias count_float count_bignum # :nodoc:

  def count_hash # :nodoc:
    allocations = 1

    @tokens.next.times do
      allocations += count
      allocations += count
    end

    allocations
  end

  def count_hash_default # :nodoc:
    count_hash + count
  end

  def count_instance_variables # :nodoc:
    allocations = 0

    @tokens.next.times do
      allocations += get_symbol
      allocations += count
    end

    allocations
  end

  def count_object # :nodoc:
    get_symbol + count_instance_variables
  end

  def count_regexp # :nodoc:
    @tokens.next
    @tokens.next

    1
  end

  alias count_string count_bignum # :nodoc:

  def count_struct # :nodoc:
    allocations = 1
    
    get_symbol

    @tokens.next.times do
      allocations += get_symbol
      allocations += count
    end

    allocations
  end

  alias count_symbol count_bignum

  def count_user_defined # :nodoc:
    allocations = get_symbol + 1

    @tokens.next

    allocations
  end

  def count_user_marshal # :nodoc:
    get_symbol + count
  end

  def get_symbol # :nodoc:
    token = @tokens.next

    case token
    when :symbol      then count_symbol
    when :symbol_link then @tokens.next; 0
    else
      raise ArgumentError, "expected SYMBOL or SYMLINK, got #{token.inspect}"
    end
  end

end


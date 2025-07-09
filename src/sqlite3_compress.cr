require "sqlite3"
require "sqlite3/type"
require "compress/gzip"
require "compress/deflate"
require "compress/zlib"

# Adds compression/decompression functions to [crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3).
#
# Functions added are:
#
#   `COMPRESS(data, method)`
#     Returns the data compressed with the given method.
#     `method` must be a string, one of: `gzip`, `deflate`, or `zlib`
#
#   `DECOMPRESS(data, method)`
#     Decompresses the data that has been previously compressed with the given method.
#     `method` must be a string, one of: `gzip`, `deflate`, or `zlib`
#
# Convenience functions are also included that include the method in the name:
#
#  Gzip:
#    `COMPRESS_GZIP(data)`, `GZIP(data)`, `DECOMPRESS_GZIP(data)`, and `UNGZIP(data)`
#  Deflate:
#    `COMPRESS_DEFLATE(data)`, `DEFLATE(data)`, `DECOMPRESS_DEFLATE(data)`, and `UNDEFLATE(data)`
#  Zlib:
#    `COMPRESS_ZLIB(data)`, `ZLIB(data)`, `DECOMPRESS_ZLIB(data)`, and `UNZLIB(data)`
#
module SQLite3::Compress
  # Register each function with the database library
  def self.register_functions(instance, db)
    check LibSQLite3.create_function(db, "compress_gzip", 1, 1, nil, COMPRESS_GZIP_FN, nil, nil)
    check LibSQLite3.create_function(db, "gzip", 1, 1, nil, COMPRESS_GZIP_FN, nil, nil)
    check LibSQLite3.create_function(db, "decompress_gzip", 1, 1, nil, DECOMPRESS_GZIP_FN, nil, nil)
    check LibSQLite3.create_function(db, "ungzip", 1, 1, nil, DECOMPRESS_GZIP_FN, nil, nil)

    check LibSQLite3.create_function(db, "compress_deflate", 1, 1, nil, COMPRESS_DEFLATE_FN, nil, nil)
    check LibSQLite3.create_function(db, "deflate", 1, 1, nil, COMPRESS_DEFLATE_FN, nil, nil)
    check LibSQLite3.create_function(db, "decompress_deflate", 1, 1, nil, DECOMPRESS_DEFLATE_FN, nil, nil)
    check LibSQLite3.create_function(db, "undeflate", 1, 1, nil, DECOMPRESS_DEFLATE_FN, nil, nil)

    check LibSQLite3.create_function(db, "compress_zlib", 1, 1, nil, COMPRESS_ZLIB_FN, nil, nil)
    check LibSQLite3.create_function(db, "zlib", 1, 1, nil, COMPRESS_ZLIB_FN, nil, nil)
    check LibSQLite3.create_function(db, "decompress_zlib", 1, 1, nil, DECOMPRESS_ZLIB_FN, nil, nil)
    check LibSQLite3.create_function(db, "unzlib", 1, 1, nil, DECOMPRESS_ZLIB_FN, nil, nil)

    check LibSQLite3.create_function(db, "compress", 2, 1, nil, COMPRESS_FN, nil, nil)
    check LibSQLite3.create_function(db, "decompress", 2, 1, nil, DECOMPRESS_FN, nil, nil)
  rescue e : SQLite3::Compress::CheckException
    raise SQLite3::Exception.new(instance)
  end

  # :nodoc:
  def self.check(code)
    raise SQLite3::Compress::CheckException.new unless code == 0
  end

  # :nodoc:
  class CheckException < ::Exception
    # :nodoc:
    def initialize
      super("a sqlite error occurred")
    end
  end

  # :nodoc:
  COMPRESS_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_bytes(argv[0])
    type = SQLite3::Compress.value_string(argv[1])
    result = case type.downcase
             when "gzip"
               SQLite3::Compress.compress_gzip(blob)
             when "deflate"
               SQLite3::Compress.compress_deflate(blob)
             when "zlib"
               SQLite3::Compress.compress_zlib(blob)
             else
               raise "#{type}: unknown compression type"
             end
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  DECOMPRESS_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_bytes(argv[0])
    type = SQLite3::Compress.value_string(argv[1])
    result = case type.downcase
             when "gzip"
               SQLite3::Compress.decompress_gzip(blob)
             when "deflate"
               SQLite3::Compress.decompress_deflate(blob)
             when "zlib"
               SQLite3::Compress.decompress_zlib(blob)
             else
               raise "#{type}: unknown compression type"
             end
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  COMPRESS_GZIP_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_to_bytes(argv[0])
    result = SQLite3::Compress.compress_gzip(blob)
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  DECOMPRESS_GZIP_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_to_bytes(argv[0])
    result = SQLite3::Compress.decompress_gzip(blob)
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  COMPRESS_DEFLATE_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_to_bytes(argv[0])
    result = SQLite3::Compress.compress_deflate(blob)
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  DECOMPRESS_DEFLATE_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_to_bytes(argv[0])
    result = SQLite3::Compress.decompress_deflate(blob)
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  COMPRESS_ZLIB_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_to_bytes(argv[0])
    result = SQLite3::Compress.compress_zlib(blob)
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  DECOMPRESS_ZLIB_FN = ->(context : LibSQLite3::SQLite3Context, _argc : Int32, argv : LibSQLite3::SQLite3Value*) do
    argv = Slice.new(argv, sizeof(Void*))
    blob = SQLite3::Compress.value_to_bytes(argv[0])
    result = SQLite3::Compress.decompress_zlib(blob)
    LibSQLite3.result_blob(context, result.to_unsafe, result.size)
    nil
  end

  # :nodoc:
  def self.value_bytes(val : LibSQLite3::SQLite3Value) : Bytes
    Bytes.new(LibSQLite3.value_blob(val), LibSQLite3.value_bytes(val))
  end

  # :nodoc:
  def self.value_string(val : LibSQLite3::SQLite3Value) : String
    String.new(LibSQLite3.value_text(val), LibSQLite3.value_bytes(val))
  end

  # :nodoc:
  def self.value_to_bytes(value : LibSQLite3::SQLite3Value)
    case SQLite3::Type.new(LibSQLite3.value_type(value))
    in SQLite3::Type::BLOB
      SQLite3::Compress.value_bytes(value)
    in SQLite3::Type::TEXT
      SQLite3::Compress.value_string(value).to_slice
    in SQLite3::Type::NULL
      Bytes.new(0)
    in SQLite3::Type::INTEGER
      LibSQLite3.value_int64(value).to_s.to_slice
    in SQLite3::Type::FLOAT
      LibSQLite3.value_double(value).to_s.to_slice
    end
  end

  # :nodoc:
  def self.compress(blob : Bytes, &) : Bytes
    buffer = IO::Memory.new
    input = IO::Memory.new blob, writeable: false
    yield buffer, input
    buffer.to_slice
  end

  # :nodoc:
  def self.decompress(blob : Bytes, &) : Bytes
    buffer = IO::Memory.new
    input = IO::Memory.new blob, writeable: false
    yield buffer, input
    buffer.to_slice
  end

  # :nodoc:
  def self.compress_gzip(blob : Bytes) : Bytes
    self.compress blob do |buffer, input|
      ::Compress::Gzip::Writer.open buffer do |output|
        IO.copy input, output
      end
    end
  end

  # :nodoc:
  def self.decompress_gzip(blob : Bytes) : Bytes
    self.decompress blob do |buffer, input|
      ::Compress::Gzip::Reader.open input do |output|
        IO.copy output, buffer
      end
    end
  end

  # :nodoc:
  def self.compress_deflate(blob : Bytes) : Bytes
    self.compress blob do |buffer, input|
      ::Compress::Deflate::Writer.open buffer do |output|
        IO.copy input, output
      end
    end
  end

  # :nodoc:
  def self.decompress_deflate(blob : Bytes) : Bytes
    self.decompress blob do |buffer, input|
      ::Compress::Deflate::Reader.open input do |output|
        IO.copy output, buffer
      end
    end
  end

  # :nodoc:
  def self.compress_zlib(blob : Bytes) : Bytes
    self.compress blob do |buffer, input|
      ::Compress::Zlib::Writer.open buffer do |output|
        IO.copy input, output
      end
    end
  end

  # :nodoc:
  def self.decompress_zlib(blob : Bytes) : Bytes
    self.decompress blob do |buffer, input|
      ::Compress::Zlib::Reader.open input do |output|
        IO.copy output, buffer
      end
    end
  end
end

class SQLite3::Connection < DB::Connection
  # :nodoc:
  def initialize(options : ::DB::Connection::Options, sqlite3_options : Options)
    previous_def(options, sqlite3_options)
    SQLite3::Compress.register_functions(self, @db)
  rescue
    raise DB::ConnectionRefused.new
  end
end

lib LibSQLite3
  fun value_type = sqlite3_value_type(SQLite3Value) : Int32
  fun value_blob = sqlite3_value_blob(SQLite3Value) : UInt8*
  fun value_bytes = sqlite3_value_bytes(SQLite3Value) : Int32
  fun value_double = sqlite3_value_double(SQLite3Value) : Float64
  fun value_int64 = sqlite3_value_int64(SQLite3Value) : Int64
  fun value_int = sqlite3_value_int(SQLite3Value) : Int32
  fun result_blob = sqlite3_result_blob(SQLite3Context, UInt8*, Int32) : Void*
end

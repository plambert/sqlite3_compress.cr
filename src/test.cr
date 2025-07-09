require "db"
require "sqlite3"
require "./sqlite3_compress"

# :nodoc:
def do_test(db, data, method : String)
  do_one_test db, data, method
  do_other_test db, data, method
end

# :nodoc:
def report_result(result, data, method, sql)
  status = result == data.to_slice ? " OK" : "FAIL"
  printf "[%4s] %s: %d bytes in, %d bytes out, %d delta bytes, sql=%s\n",
    status,
    method,
    data.to_slice.size,
    result.size,
    result.size - data.size,
    sql.inspect
end

# :nodoc:
def do_one_test(db, data, method : String)
  sql = "SELECT decompress_#{method}(compress_#{method}(?))"
  result = db.query_one sql, data.to_slice, as: Bytes
  report_result result, data, method, sql
end

# :nodoc:
def do_other_test(db, data, method : String)
  sql = "SELECT decompress(compress(?, '#{method}'), '#{method}')"
  result = db.query_one sql, data.to_slice, as: Bytes
  report_result result, data, method, sql
end

# ameba:disable Naming/BlockParameterName
DB.open "sqlite3:%3Amemory%3A" do |db|
  db.exec "CREATE TABLE test (id INTEGER PRIMARY KEY, data BLOB NOT NULL)"
  data = File.read "./README.md"
  # gzip_data = db.query_one "SELECT gzip(?)", data.to_slice, as: Bytes
  # puts "data: #{data.size}, gzip: #{gzip_data.size}"
  # ungzip_data = db.query_one "SELECT ungzip(?)", gzip_data, as: Bytes
  # puts "decompressed: #{ungzip_data.size}"
  # gzip_data = SQLite3.compress_gzip(data.to_slice)
  # ungzip_data = SQLite3.decompress_gzip(gzip_data)
  # puts "original: #{data.size}, gzip: #{gzip_data.size}, ungzip: #{ungzip_data.size}"
  do_test db, data, "gzip"
  do_test db, data, "deflate"
  do_test db, data, "zlib"
  # result = db.query_one "SELECT decompress_gzip(compress_gzip(?))", data.to_slice

  # db.exec "INSERT INTO test (data) VALUES (compress_gzip(?))", data.to_slice
  # db.exec "INSERT INTO test (data) VALUES (gzip(?))", data.to_slice
  # db.exec "INSERT INTO test (data) VALUES (compress_deflate(?))", data.to_slice
  # db.exec "INSERT INTO test (data) VALUES (deflate(?))", data.to_slice

end

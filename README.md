# sqlite3_compress

Adds compression/decompression functions to [crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3).

Can also serve as an example of how to create custom functions in sqlite.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     sqlite3_uri:
       github: plambert/sqlite3_compress.cr
   ```

2. Run `shards install`

Both `db` and `sqlite3` will be brought in as dependencies by this shard; you don't need
to specify them separately in your `shard.yml`.

## Usage

```crystal
require "./sqlite3_compress"
require "http/client"
require "uri"

DB.open "sqlite3:%3Amemory%3A" do |db|
  db.exec "CREATE TABLE example (id INTEGER PRIMARY KEY, url TEXT NOT NULL, gzip_html BLOB NOT NULL)"
  ARGV.map { |arg| URI.parse arg }.each do |url|
    response = HTTP::Client.get url
    while response.status_code < 400 && response.status_code >= 300
      loc = response.headers["location"]? || raise RuntimeError.new "#{url}: returned a #{response.status_code} but no location header"
      url = url.resolve(loc)
      response = HTTP::Client.get url
    end
    if response.success?
      content = response.body
      if content.empty?
        STDERR.puts "[ERROR] empty response: #{url}"
      else
        db.exec "INSERT INTO example (url, gzip_html) VALUES (?, compress_gzip(?))", url.to_s, content
      end
    else
      STDERR.puts "[ERROR] #{response.status_code} #{response.status_message}: #{url}"
    end
  end

  sql = "
    SELECT url,
           LENGTH(gzip_html) AS compressed_size,
           LENGTH(decompress_gzip(gzip_html)) AS uncompressed_size
    FROM example
  "
  report = db.query_all sql, as: {String, Int64, Int64}
  unless report.empty?
    printf "%12s %12s %6s   %s\n", "uncompressed", "compressed", "saved", "url"
    report.each do |url, compressed, uncompressed|
      printf "%12d %12d %6.2f%%  %s\n", uncompressed, compressed, 100_f64*(uncompressed - compressed)/uncompressed, url
    end
  end
end
```

## Documentation

The functions added are:
  * `COMPRESS(data, method)`
    - Returns the data compressed with the given method.
      <br> `method` must be a string, one of: `gzip`, `deflate`, or `zlib`
  * `DECOMPRESS(data, method)`
    - Decompresses the data that has been previously compressed with the given method.
      <br> `method` must be a string, one of: `gzip`, `deflate`, or `zlib`

Convenience functions are also included that include the method in the name:

 * Gzip:
   - `COMPRESS_GZIP(data)`, `GZIP(data)`, `DECOMPRESS_GZIP(data)`, and `UNGZIP(data)`
 * Deflate:
   - `COMPRESS_DEFLATE(data)`, `DEFLATE(data)`, `DECOMPRESS_DEFLATE(data)`, and `UNDEFLATE(data)`
 * Zlib:
   - `COMPRESS_ZLIB(data)`, `ZLIB(data)`, `DECOMPRESS_ZLIB(data)`, and `UNZLIB(data)`

You can then use these anywhere you would normally use a scalar function.

## Examples

Create a table with an id as the primary key and a column to hold some data compressed with the gzip algorithm.

```crystal
db.exec "CREATE TABLE table (id INTEGER PRIMARY KEY, compressed_data_gzip BLOB NOT NULL)"
```

Now insert some data into it.

```crystal
db.exec "INSERT INTO table (id, compressed_data_gzip) VALUES (?, COMPRESS(?, 'gzip'))", id, data
```

Let's get the original data for a specific id:

```crystal
data_for_id = db.query_one? "SELECT DECOMPRESS(compressed_data_gzip, 'gzip') FROM table WHERE id=?", id, as: String
```

To make it easier on ourselves when we want to look at or search the uncompressed data, we can make a view.


```crystal
db.exec "CREATE VIEW uncompressed_table AS SELECT id, DECOMPRESS_GZIP(compressed_data_gzip) AS data FROM table"
```

But now, using the view, we cannot insert or change any of the data. While we could just remember to do all updates or inserts on the original table, we could also use `INSTEAD OF` triggers:

```crystal
db.exec "
  CREATE TRIGGER trg_uncompressed_table_instead_of_insert
    INSTEAD OF INSERT ON uncompressed_table
    BEGIN
      INSERT INTO table(id, compressed_data_gzip)
      VALUES (NEW.id, COMPRESS_GZIP(NEW.data))
    END
"

db.exec "
  CREATE TRIGGER trg_uncompressed_table_instead_of_update
    INSTEAD OF UDPATE OF data ON uncompressed_table
    BEGIN
      UPDATE table
      SET compressed_data_gzip = COMPRESS_GZIP(NEW.data)
      WHERE table.id = NEW.id;
    END
"
```

This should let us do an insert on the view, and have it automatically change to be an insert on the underlying table:

```crystal
db.exec "INSERT INTO uncompressed_table (data) VALUES (?)", my_data
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/plambert/sqlite3_compress.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Paul M. Lambert](https://github.com/plambert) - creator and maintainer

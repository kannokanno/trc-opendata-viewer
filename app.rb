require 'sinatra'
require 'sinatra/reloader' if development?
require 'slim'
require 'zip'
require 'csv'
# kaminariが内部で依存しているのでrequire必須
require 'padrino-helpers'
require 'active_support/core_ext/hash'

require 'kaminari/sinatra'

register Kaminari::Helpers::SinatraHelpers

# 引用元: http://www.gesource.jp/weblog/?p=430
def isbn13_to_10(isbn)
  return isbn if isbn.length == 10

  isbn10 = isbn[3..11]
  check_digit = 0
  isbn10.split(//).each_with_index do |chr, idx|
    check_digit += chr.to_i * (10 - idx)
  end
  check_digit = 11 - (check_digit % 11)
  case check_digit
  when 10
    check_digit = "X"
  when 11
    check_digit = 0
  end
  "#{isbn10}#{check_digit}"
end

def unzip_trc(path)
  offset = 0
  Zip::InputStream.open(path, offset) do |input|
    # zipの中身は1ファイルしかない前提
    # 複数ファイルが存在する場合は想定外なので、仕様を確認して組み直す
    # (TODO ちゃんとやるなら、それに気付くためのログを仕込んだ方がいい)
    input.get_next_entry

    tsv = input.read.force_encoding("utf-8")
    rows = CSV.parse(tsv, col_sep: "\t", headers: false)
    # isbnがないデータは除外
    rows.reject {|row| row[0].nil? }.map do |row|
      {
        isbn: row[0],
        title: row[1],
        author: row[3],
        publisher: row[6],
      }
    end
  end
end

def fetch_newly_books
  trc_records = unzip_trc('./data/TRCOpenBibData_20170902.zip')
  trc_records.map {|item|
    isbn = item[:isbn].gsub('-', '')
    item[:img] = "https://cover.openbd.jp/#{isbn}.jpg"
    item[:href] = "https://www.amazon.co.jp/gp/product/#{isbn13_to_10(isbn)}"
    item[:author] = (item[:author] || '').gsub(/ 著|編|監修|原作・?|作|漫?画/, '')
    item
  }
end


get '/' do
  @books = Kaminari.paginate_array(fetch_newly_books).page(params[:page]).per(50)
  slim :index
end

not_found do
  redirect '/'
end

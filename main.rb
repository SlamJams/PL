require 'net/http'
require 'uri'
require 'nokogiri'
require 'thread'

def read_file
    content = File.readlines("isbnList.txt").collect{ |e| e.strip || e}
    content.pop if content.last == ""
    content
end

def get_title_and_rank_for_all_isbns(isbns)
    isbns.map { |e| get_title_and_rank_for_isbn(e) }
end

def get_title_and_rank_for_isbn(isbn)
    books = Hash.new
    encoded_url = URI.encode('https://www.amazon.com/exec/obidos/ASIN/' + isbn) 
    url = URI.parse(encoded_url)

    response = Net::HTTP.start(url.host, use_ssl: true) do |http|
        http.get url.request_uri, 'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.71 Safari/537.36'
    end

    page = Nokogiri::HTML response.body
    bookName =  page.css('#productTitle').text
    bookRank = page.css('#SalesRank').text[/\#.*\)/]
    bookRank.slice! " in Books (See Top 100 in Books)"
    bookRank = bookRank.gsub(/[^0-9]/, "").to_i     
    books = ({:title => bookName, :ISBN => isbn, :rank => bookRank})
end

def print_report(start, titleAndRanks)
    puts "%-90s %-15s %-8s" %["Book Title", "ISBN", "Rank"]
    puts titleAndRanks.sort_by{ |e| e[:rank] }.collect{ |e|
        "%-90s %-15s %-8s" % [e[:title], e[:ISBN], e[:rank]]
    }
    finish = Time.now
    puts "Program completed in #{finish - start} seconds."
    puts
end

def sequential_run(isbns)
    start = Time.now
    titleAndRanks = get_title_and_rank_for_all_isbns(isbns)
    print_report(start, titleAndRanks)
end

def concurrent_run(isbns)
    start = Time.now
    titleAndRanks = get_title_and_rank_for_isbn_concurrent(isbns)
    print_report(start, titleAndRanks)
end
    
def lock_free_run(isbns)
    start = Time.now
    titleAndRanks = get_title_and_rank_for_isbn_lock_free(isbns)
    print_report(start, titleAndRanks)
end
    

def get_title_and_rank_for_isbn_concurrent(isbn)

    mutex = Mutex.new
    titleAndRanks = Array.new
    threads = []

    for e in isbn
        threads << Thread.new(e) do |e|
            
            book = get_title_and_rank_for_isbn(e) 

            mutex.synchronize do
                titleAndRanks.push(book)
            end 
        end
    end

    threads.map(&:join) 
    titleAndRanks   
end
    
def get_title_and_rank_for_isbn_lock_free(isbn)
    
    bookData = Array.new
    threads = []

    for e in isbn
        threads << Thread.new(e) do |e|
            get_title_and_rank_for_isbn(e)
        end
    end

    threads.map { |e| bookData << e.value }
    bookData
end

isbns = read_file
sequential_run(isbns)
concurrent_run(isbns)
lock_free_run(isbns)
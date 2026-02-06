#!/usr/bin/env ruby

require 'csv'
require 'set'
require 'active_model'
#require './vendor_map.rb'
require 'debug'


SQUARE_VENDOR_TO_SHOPIFY_VENDOR_LOOKUP = {
  "Amy Rose WS" => "Amy Rose Moore",
  "Bad Attitude Bunny Illustration" => "Bad Attitude Bunny",
  "Bored Inc" => "Bored Inc.",
  "Brenna Daugherty WS" => "Brenna Daugherty",
  "Cat City" => "Cat City, Ink",
  "Chanamon WS" => "Made by Chanamon",
  "Diamond L Leatherworks" => "Ork",
  "Heliotrope WS" => "Heliotrope",
  "Lady Alamo WS" => "Lady Alamo",
  "Local Take - 3 Fish Studios" => "3 Fish Studios",
  "Local Take - Amano" => "Amano Studio",
  "Local Take - Bag" => "Spicer Bags",
  "Local Take - Cavallini" => "Cavallini",
  "Local Take - Rickshaw" => "Rickshaw Bags",
  "Local Take, Trays4Us WS" => "Trays4Us",
  "Mojo Bakes SF" => "Mojo Bakes",
  "Noteify WS" => "Noteify",
  "Ork Inc" => "Ork",
  "SF Mercantile - LT" => "SF Mercantile",
  "Steamer Lane Design" => "Steamer Lane",
  "Sundrop Jewelry" => "Sundrop",
  'Tickle & Smash' => 'Tickle and Smash',
"Trays4Us WS" => "Trays4Us",
  "Unpossible Cuts WS" => "Unpossible Cuts",
  "Yellow Daisy Paper Co" => "Yellow Daisy",
}.freeze

class Item

  def initialize(row:)
    @row = row
  end

  def price
    @price ||= begin
      return nil if raw_price.nil? || raw_price.to_s.strip.empty?
      raw_price.to_s.strip.gsub(/[^0-9.]/, '').to_f
    end
  end

  def vendor
    @vendor ||= SQUARE_VENDOR_TO_SHOPIFY_VENDOR_LOOKUP.fetch(raw_vendor, raw_vendor)
  end

  def title
    @title ||= (normalize_title(raw_title) + ' ' + normalize_string(extras)).strip
  end

  def title_words
    vendor_words = vendor.strip.downcase.split(/\s+/)
    @title_words ||= title.split(/\s+/).filter_map do |word|
      next unless word.length > 1
      next if vendor_words.include?(word)
      word.strip
    end.uniq
  end

  def extras
    @extras ||= begin
      extras = [ @row['Option1 Name'], @row['Option1 Value'] ].filter_map do |extra|
        next if extra.nil? || extra.to_s.strip.empty?
        extra.gsub!(%r{default|title|size|option|color}i, '')
        extra.strip!
        next if extra.nil? || extra.empty?
        extra
      end
      extras.join(' ')
    end
  end

  private

  def normalize_string(str)
    return '' if str.nil?
    str
    .tr("+", "&")
    .gsub("&", 'and')
    .to_s
    .strip
    .downcase
  end

  def normalize_title(str)
    normalize_string(str).gsub(%r{san francisco}, 'sf')
      .tr("-", ' ')
      .gsub(%r{golden gate}, 'gg')
      .gsub(%r{\bwom\b}, 'women')
  end

  def raw_price
    raise NotImplementedError, "Subclasses must implement raw_price"
  end

  def raw_vendor
    raise NotImplementedError, "Subclasses must implement raw_vendor"
  end

  def raw_title
    raise NotImplementedError, "Subclasses must implement raw_title"
  end

end

class ShopifyItem < Item

  def initialize(row)
    super(row:)
  end
  private

  def raw_price
    @row['Variant Price']
  end

  def raw_vendor
    @row['Vendor']
  end

  def raw_title
    (@row['Title'] + ' ' + @row['Option1 Name'] + ' ' + @row['Option1 Value'])
      .gsub(%r{default|title|default title}i, '')
      .gsub(vendor.strip.downcase, '')
      .strip
  end
end

class SquareItem < Item
  def initialize(row)
    super(row:)
  end
  private
  def raw_price
    @row['Price']
  end

  def raw_vendor
    @row['Reporting Category']
  end

  def raw_title
    @row['Item Name']
  end
end

class ProductMatcher
  SIMILARITY_THRESHOLD = 0.39999

  def initialize(shopify_file, square_file, output_file)
    @shopify_file = shopify_file
    @square_file = square_file
    @output_file = output_file
    @shopify_rows = []
    @square_rows = []
    @matched_square_indices = Set.new
  end

  def normalize_string(str)
    return '' if str.nil?
    str
    .to_s
    .strip
    .downcase
  end

  def normalize_price(price_str)
    return nil if price_str.nil? || price_str.to_s.strip.empty?
    price_str.to_s.strip.gsub(/[^0-9.]/, '').to_f
  end

  def words_match?(item1, item2)
    item1.title_words == item2.title_words
  end

  def fuzzy_title_match?(item1, item2)
    score =fuzzy_title_score(item1, item2)
    return :partial if score >= SIMILARITY_THRESHOLD
  end

  def fuzzy_title_score(item1, item2)
    title1 = item1.title
    title2 = item2.title
    # Exact match
    return 1 if title1 == title2

    # Word order match (same words, different order)
    return 0.8 if words_match?(item1, item2)

    # Partial match (one contains the other or significant overlap)
    words1 = item1.title_words
    words2 = item2.title_words

    common_words = words1 & words2
    total_words = (words1 | words2).size
    word_similarity = total_words > 0 ? (common_words.size.to_f / total_words) : 0.0

    order_match_count = 0

    common_words1 = words1 & common_words
    common_words2 = words2 & common_words
    common_words1.each_with_index do |word,idx|
      common_word2 = common_words2[idx]
      break if common_word2.nil?
      break if word != common_word2
      order_match_count += 1
    end

    order_similarity = order_match_count.to_f / (words1 + words2).uniq.size

    similarity = 0.6 * word_similarity + 0.4 * order_similarity
    # puts "words1: #{words1}"
    # puts "words2: #{words2}"
    # puts "Similarity #{word_similarity} #{order_similarity} #{similarity}"
    return similarity
  end

  def vendor_match?(item1, item2)
    v1 = item1.vendor
    v2 = item2.vendor

    return false if v1.blank? || v2.blank?
    return true if v1 == v2
    return true if VENDOR_MAP.key?(v1) && VENDOR_MAP[v1] == v2
    return true if v1.include?(v2) || v2.include?(v1)
    false
  end

  def price_match?(item1, item2)
    price1 = item1.price
    price2 = item2.price
    return true if price1.nil? || price2.nil? # Skip price check if either is missing
    (price1 - price2).abs < 1.1# Allow small floating point differences
  end

  def calculate_confidence(shopify_row, square_row, match_type)
    square_item = SquareItem.new(square_row)
    shopify_item = ShopifyItem.new(shopify_row)
    square_title = square_row['Item Name']
    shopify_title = shopify_row['Title']
    square_price = square_row['Price']
    shopify_price = shopify_row['Variant Price']

    vendor_matches = vendor_match?(square_item, shopify_item)
    title_match_type = fuzzy_title_match?(square_item, shopify_item)
    price_matches = price_match?(square_item, shopify_item)


    # High confidence: exact match on all fields
    if match_type == :exact && vendor_matches && title_match_type == :exact && price_matches
      return 'High'
    end

    # If vendors don't match, confidence is low
    unless vendor_matches
      return 'Low'
    end

    # Medium confidence: vendor matches, title is fuzzy (word order or partial)
    if vendor_matches && (title_match_type == :word_order || title_match_type == :partial)
      return 'Medium'
    end

    # High confidence: vendor matches, title exact or very close, price matches
    if vendor_matches && (title_match_type == :exact || title_match_type == :word_order) && price_matches
      return 'High'
    end

    # Default to medium if vendor matches
    vendor_matches ? 'Medium' : 'Low'
  end

  def find_matches(square_row)
    matches = []
    square_item = SquareItem.new(square_row)
    square_vendor = normalize_string(square_row['Default Vendor Name'])
#    square_category = normalize_string(square_row['Categories'])
    square_title = square_row['Item Name']
    square_price = square_row['Price']

    @shopify_rows.each_with_index do |shopify_row, idx|
      shopify_item = ShopifyItem.new(shopify_row)
      shopify_vendor = normalize_string(shopify_row['Vendor'])
#      shopify_category = normalize_string(shopify_row['Product Category'])
      shopify_title = shopify_row['Title']
      shopify_price = shopify_row['Variant Price']

      if !vendor_match?(square_item, shopify_item)
        next
      end

      if !price_match?(square_item, shopify_item)
        next
      end

      if shopify_item.title == square_item.title
        matches << { row: shopify_row, index: idx, match_type: :exact, score: 1 }
        next
      end

      # Fuzzy match - vendor must match, category should match, title can be fuzzy
      if vendor_match?(square_item, shopify_item) &&
        price_match?(square_item, shopify_item)
        score = fuzzy_title_score(square_item, shopify_item)
        matches << { row: shopify_row, index: idx, match_type: :fuzzy , score:}
      end
    end

    matches
  end

  def create_shopify_row_from_square(square_row)
    # Create a new row with Square data mapped to Shopify format
    row = {}

    # Map key fields
    row['Title'] = square_row['Item Name'] || square_row['Customer-facing Name'] || ''
    row['Vendor'] = square_row['Categories'] || ''
    row['Variant SKU'] = square_row['SKU'] || ''
    row['Variant Price'] = square_row['Price'] || ''
    row['Body (HTML)'] = square_row['Description'] || ''

    # Generate handle from title
    handle = normalize_string(row['Title'])
      .gsub(/[^a-z0-9]+/, '-')
      .gsub(/^-+|-+$/, '')
    row['Handle'] = handle

    # Set defaults
    row['Published'] = 'TRUE'
    row['Variant Requires Shipping'] = 'TRUE'
    row['Variant Taxable'] = 'TRUE'
    row['Status'] = 'active'

    row
  end

  def load_data
    puts "Loading Shopify data..."
    @shopify_headers = nil
    CSV.foreach(@shopify_file, headers: true, encoding: 'UTF-8') do |row|
      @shopify_headers = row.headers if @shopify_headers.nil?
      @shopify_rows << row.to_h
    end
    puts "Loaded #{@shopify_rows.size} Shopify rows"

    puts "Loading Square data..."
    @square_headers = nil
    CSV.foreach(@square_file, headers: true, encoding: 'UTF-8') do |row|
      @square_headers = row.headers if @square_headers.nil?
      @square_rows << row.to_h
    end
    puts "Loaded #{@square_rows.size} Square rows"
  end

  def process
    load_data

    output_rows = []
    matched_count = 0
    unmatched_count = 0
    duplicate_count = 0

    puts "\nProcessing Square rows..."

    @square_rows.each_with_index do |square_row, square_idx|
      matches = find_matches(square_row)

      if matches.empty?
        # No match found - create new row
        new_row = create_shopify_row_from_square(square_row)
        # Fill in all Shopify columns
        @shopify_headers.each do |header|
          new_row[header] = new_row[header] || ''
        end
        new_row['Match Confidence'] = 'No Match'
        new_row['Match Notes'] = 'New row created from Square data'
        new_row['Square Title'] = square_row['Item Name']
        output_rows << new_row
        unmatched_count += 1
      else
        # Found matches
        if matches.size > 1
          duplicate_count += 1
        end
        puts "Matches:"
        matches.sort_by { |match| -match[:score] }.first(4).each do |match|
          puts "  #{match[:score]}\t#{match[:row]['Title']} <> #{square_row['Item Name']}"
        end
        match = matches.max_by{ |match| match[:score] }

        shopify_row = match[:row].dup
        confidence = calculate_confidence(shopify_row, square_row, match[:match_type])
        next if match[:score] < SIMILARITY_THRESHOLD

        # Add Square SKU to Variant SKU (append if already exists)
        if shopify_row['Variant SKU'].to_s.strip.empty?
          shopify_row['Variant SKU'] = square_row['SKU'] || ''
        else
          existing_sku = shopify_row['Variant SKU']
          new_sku = square_row['SKU'] || ''
          shopify_row['Variant SKU'] = "#{existing_sku}, #{new_sku}".strip
        end

        # puts '---'
        # puts "best match: #{match[:score]}"
        # puts "confidence: #{confidence}"
        # puts "match type: #{match[:match_type]}"
        # puts "square: #{square_row['Item Name']}"
        # puts "shopify: #{shopify_row['Title']}"
        # puts "shopify sku: #{shopify_row['Variant SKU']}"
        # puts "shopify: #{shopify_row['Variant Price']}"

        shopify_row['Match Confidence'] = confidence
        if matches.size > 1
          shopify_row['Match Notes'] = "Multiple matches found (#{matches.size} total)"
        else
          shopify_row['Match Notes'] = ''
        end
        shopify_row['Square Title'] = square_row['Item Name']

        output_rows << shopify_row

#        good_matches << shopify_row
#       bad_matches += matches.reject { |match| match == match }

        matched_count += 1
        @matched_square_indices.add(square_idx)
      end

      if (square_idx + 1) % 100 == 0
        puts "  Processed #{square_idx + 1}/#{@square_rows.size} Square rows..."
      end
    end

    # Add unmatched Shopify rows (rows that weren't matched to any Square item)
    puts "\nAdding unmatched Shopify rows..."
    shopify_matched_indices = Set.new
    output_rows.each do |row|
      # Try to find the original Shopify row index
      @shopify_rows.each_with_index do |shopify_row, idx|
        if row['Title'] == shopify_row['Title'] &&
           row['Vendor'] == shopify_row['Vendor'] &&
           row['Product Category'] == shopify_row['Product Category']
          shopify_matched_indices.add(idx)
          break
        end
      end
    end

    @shopify_rows.each_with_index do |shopify_row, idx|
      unless shopify_matched_indices.include?(idx)
        new_row = shopify_row.dup
        new_row['Match Confidence'] = 'No Match'
        new_row['Match Notes'] = 'Shopify row with no Square match'
        output_rows << new_row
      end
    end

    puts "\nWriting output..."
    write_output(output_rows)

    puts "\n=== Summary ==="
    puts "Total output rows: #{output_rows.size}"
    puts "Square rows matched: #{matched_count}"
    puts "Square rows unmatched (new rows created): #{unmatched_count}"
    puts "Duplicate matches: #{duplicate_count}"
    puts "Output written to: #{@output_file}"
  end

  def write_output(rows)
    # Get all headers including new ones
    all_headers = @shopify_headers.dup
    all_headers << 'Match Confidence' unless all_headers.include?('Match Confidence')
    all_headers << 'Match Notes' unless all_headers.include?('Match Notes')
    all_headers << 'Square Title' unless all_headers.include?('Square Title')
    all_headers.sort_by! do |h|
      case h.downcase
      when 'title'
        1
      when 'square title'
        2
      when 'vendor'
        0
      when 'variant sku'
        3
      when 'sku'
        3
      else
        10
      end
    end
    CSV.open(@output_file, 'w', write_headers: true, headers: all_headers, encoding: 'UTF-8') do |csv|
      rows.each do |row|
        csv << all_headers.map { |h| row[h] || '' }
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  vendor = 'Heliotrope'
  vendor = 'SF Candle'
  vendor = "Tickle and Smash"
  vendor = "Animal Instincts"
  shopify_file = 'Shopify product list_' + vendor + '.csv'
  square_file = 'Square product export 1_' + vendor + '.csv'
  output_file = 'Merged product list_' + vendor + '.csv'

  matcher = ProductMatcher.new(shopify_file, square_file, output_file)
  matcher.process
end

#!/usr/bin/env ruby

require 'csv'
require 'active_model'
# require './vendor_map.rb'
require 'debug'

DEBUG = 0
SQUARE_VENDOR_TO_SHOPIFY_VENDOR_LOOKUP = {
  'Amy Rose WS' => 'Amy Rose Moore',
  'Bad Attitude Bunny Illustration' => 'Bad Attitude Bunny',
  'Bored Inc' => 'Bored Inc.',
  'Brenna Daugherty WS' => 'Brenna Daugherty',
  'Cat City' => 'Cat City, Ink',
  'Chanamon WS' => 'Made by Chanamon',
  'Diamond L Leatherworks' => 'Ork',
  'Heliotrope WS' => 'Heliotrope',
  'Lady Alamo WS' => 'Lady Alamo',
  'Local Notion' => 'San Francycle',
  'Local Take - 3 Fish Studios' => '3 Fish Studios',
  'Local Take - Amano' => 'Amano Studio',
  'Local Take - Bag' => 'Spicer Bags',
  'Local Take - Cavallini' => 'Cavallini',
  'Local Take - Rickshaw' => 'Rickshaw Bags',
  'Local Take, Trays4Us WS' => 'Trays4Us',
  'Mission Thread Clothing' => 'Mission Threads',
  'Mojo Bakes SF' => 'Mojo Bakes',
  'Nidhi Chanani' => 'Everyday Love',
  'Noteify WS' => 'Noteify',
  'Ork Inc' => 'Ork',
  'Pretty Alright Goods' => 'The Matt Butler',
  'Rover & Kin' => 'Rover + Kin',
  'SF Mercantile - LT' => 'SF Mercantile',
  'Shawn R Harris' => 'Shawn Ray Harris',
  'Sincerely\, Rob' => 'Sincerely, Rob',
  'Space46' => 'Space 49',
  'Steamer Lane Design' => 'Steamer Lane',
  'Sundrop Jewelry' => 'Sundrop',
  'Tickle & Smash' => 'Tickle and Smash',
  'TMK Design' => 'Tomoko Maruyama',
  'Trays4Us WS' => 'Trays4Us',
  'Unpossible Cuts WS' => 'Unpossible Cuts',
  'Yellow Daisy Paper Co' => 'Yellow Daisy',
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
      extras = [@row['Option1 Name'], @row['Option1 Value']].filter_map do |extra|
        next if extra.nil? || extra.to_s.strip.empty?

        extra.gsub!(/default|title|size|option|color/i, '')
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
      .tr('+', '&')
      .gsub('&', 'and')
      .to_s
      .strip
      .downcase
  end

  def normalize_title(str)
    normalize_string(str)
      .tr('-', ' ')
      .gsub(/\bl\b/, 'large')
      .gsub(/\blg\b/, 'large')
      .gsub(/\bm\b/, 'medium')
      .gsub(/\bmd\b/, 'medium')
      .gsub(/\bs\b/, 'small')
      .gsub(/\bsm\b/, 'small')
      .gsub(/\bxl\b/, 'extra-large')
      .gsub(/\bls\b/, 'long sleeve')
      .gsub(/\b5x7\b/, '5x7 print')
      .gsub(/\b8x8\b/, '8x8 print')
      .gsub(/\b8x10\b/, '8x10 print')
      .gsub(/\b8x12\b/, '8x12 print')
      .gsub(/\b9x12\b/, '9x12 print')
      .gsub(/\b11x14\b/, '11x14 print')
      .gsub(/\b11x17\b/, '11x17 print')
      .gsub(/\b16x16\b/, '16x16 print')
      .gsub(/\b16x20\b/, '16x20 print')
      .gsub(/\bkey tag\b/, 'keychain')
      .gsub(/\bggb\b/, 'golden gate bridge')
      .gsub(/\bsf\b/, 'san francisco')
      .gsub(/\bgg\b/, 'golden gate')
      .gsub(/\bwom\b/, 'womens')
      .gsub(/\bwomen's\b/, 'womens')
      .gsub(/\bmen's\b/, 'mens')
      .gsub(/\bca\b/, 'california')
      .gsub(/\bcali\b/, 'california')
      .gsub(/\bstud\b/, 'studs')
      .gsub(/\bneck\b/, 'necklace')
      .gsub(/\bghidorrah\b/, 'ghidorah')
      .gsub(/\bblk\b/, 'black')
      .gsub(/\bwht\b/, 'white')
      .gsub(/\bgrn\b/, 'green')
      .gsub(/\bblu\b/, 'blue')
      .gsub(/\bnec\b/, 'necklace')
      .gsub(/\bneck\b/, 'necklace')
      .gsub(/\bwomen\b/, 'womens')
      .gsub(/\b12x12\b/, 'art print')
      .gsub(/\bdopp\b/,  'box zip')
      .gsub(/\brbg\b/, 'ruth bader ginsberg')
  end

  def raw_price
    raise NotImplementedError, 'Subclasses must implement raw_price'
  end

  def raw_vendor
    raise NotImplementedError, 'Subclasses must implement raw_vendor'
  end

  def raw_title
    raise NotImplementedError, 'Subclasses must implement raw_title'
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
    (@row['Title'].to_s + ' ' + @row['Option1 Name'].to_s + ' ' + @row['Option1 Value'].to_s)
      .gsub(/default|title|default title/i, '')
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
    @intervention_file = output_file.gsub(/\.csv$/, '.intervention.csv')
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
    score = fuzzy_title_score(item1, item2)

    :partial if score >= SIMILARITY_THRESHOLD
  end

  def fuzzy_title_score(item1, item2)
    title1 = item1.title
    title2 = item2.title
    return 0 if title1.empty? || title2.empty?
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
    common_words1.each_with_index do |word, idx|
      common_word2 = common_words2[idx]
      break if common_word2.nil?
      break if word != common_word2

      order_match_count += 1
    end

    order_similarity = order_match_count.to_f / (words1 + words2).uniq.size

    similarity = (0.6 * word_similarity) + (0.4 * order_similarity)

    if DEBUG == 1
      puts "words1: #{words1}"
      puts "words2: #{words2}"
      puts "Similarity #{word_similarity} #{order_similarity} #{similarity}"
    end
    similarity
  end

  def vendor_match?(item1, item2)
    v1 = item1.vendor
    v2 = item2.vendor

    return false if v1.blank? || v2.blank?
    return true if v1 == v2
    return true if v1.include?(v2) || v2.include?(v1)

    false
  end

  def price_match?(item1, item2)
    price1 = item1.price
    price2 = item2.price
    return true if price1.nil? || price2.nil? # Skip price check if either is missing

    (price1 - price2).abs < 1.1 # Allow small floating point differences
  end

  def calculate_confidence(shopify_row, square_row, match_type)
    square_item = SquareItem.new(square_row)
    shopify_item = ShopifyItem.new(shopify_row)
    square_row['Item Name']
    shopify_row['Title']
    square_row['Price']
    shopify_row['Variant Price']

    vendor_matches = vendor_match?(square_item, shopify_item)
    title_match_type = fuzzy_title_match?(square_item, shopify_item)
    price_matches = price_match?(square_item, shopify_item)

    # High confidence: exact match on all fields
    return 'High' if match_type == :exact && vendor_matches && title_match_type == :exact && price_matches

    # If vendors don't match, confidence is low
    return 'No vendor match' unless vendor_matches

    # Medium confidence: vendor matches, title is fuzzy (word order or partial)
    if %i[word_order partial].include?(title_match_type)
      return "medium title match#{" prices don't match" unless price_matches}"
    end

    # High confidence: vendor matches, title exact or very close, price matches
    return 'good title match + price' if %i[exact word_order].include?(title_match_type) && price_matches

    'vendor and price match'
  end

  def find_matches(square_row)
    matches = []
    square_item = SquareItem.new(square_row)
    normalize_string(square_row['Default Vendor Name'])
    #    square_category = normalize_string(square_row['Categories'])
    square_row['Item Name']
    square_row['Price']

    @shopify_rows.each_with_index do |shopify_row, idx|
      shopify_item = ShopifyItem.new(shopify_row)
      normalize_string(shopify_row['Vendor'])
      #      shopify_category = normalize_string(shopify_row['Product Category'])
      shopify_row['Title']
      shopify_row['Variant Price']

      next unless vendor_match?(square_item, shopify_item)

      if shopify_item.title == square_item.title
        matches << { row: shopify_row, index: idx, match_type: :exact, score: 1 }
        next
      end

      # Fuzzy match - vendor must match, category should match, title can be fuzzy
      if vendor_match?(square_item, shopify_item) &&
         score = fuzzy_title_score(square_item, shopify_item)
        matches << { row: shopify_row, index: idx, match_type: :fuzzy, score: }
      end
    end

    matches
  end

  def create_shopify_row_from_square(square_row, expected_headers)
    # Create a new row with Square data mapped to Shopify format
    row = {}

    # Map key fields
    row['Title'] = square_row['Item Name'] || square_row['Customer-facing Name'] || ''
    vendor = square_row['Categories'] || ''
    row['Vendor'] = SQUARE_VENDOR_TO_SHOPIFY_VENDOR_LOOKUP.fetch(vendor, vendor)
    row['Variant SKU'] = square_row['SKU'] || ''
    row['Variant Barcode'] = row['Variant SKU']
    row['Variant Price'] = square_row['Price'] || ''
    row['Body (HTML)'] = square_row['Description'] || ''
    row['Variant Inventory Qty'] = square_row['Current Quantity Castro'] || ''
    # Set defaults
    row['Published'] = 'TRUE'
    row['Variant Requires Shipping'] = 'TRUE'
    row['Variant Taxable'] = 'TRUE'
    row['Status'] = 'active'

    # Fill in all Shopify columns
    @shopify_headers.each do |header|
      row[header] = row[header] || ''
    end

    row['Match Confidence'] = 'No Match'
    row['Match Notes'] = 'New row created from Square data'
    row['Square Title'] = square_row['Item Name']
    row["Square Token"] = square_row['Token']

    row
  end

  def load_data
    puts "Loading Shopify data from #{@shopify_file}..."
    @shopify_headers = nil
    CSV.foreach(@shopify_file, headers: true, encoding: 'UTF-8') do |row|
      @shopify_headers = row.headers if @shopify_headers.nil?
      @shopify_rows << row.to_h if row['Title'].present?
    end
    puts "Loaded #{@shopify_rows.size} Shopify rows"

    puts "Loading Square data from #{@square_file}..."
    @square_headers = nil
    CSV.foreach(@square_file, headers: true, encoding: 'UTF-8') do |row|
      @square_headers = row.headers if @square_headers.nil?
      @square_rows << row.to_h if row['Item Name'].present?
    end
    puts "Loaded #{@square_rows.size} Square rows"
  end

  def process
    load_data

    output_rows = []
    manual_intervention_rows = []
    matched_count = 0
    unmatched_count = 0
    duplicate_count = 0
    handles = Set.new

    puts "\nProcessing Square rows..."

    @square_rows.each_with_index do |square_row, square_idx|
      matches = find_matches(square_row)

      if matches.empty?
        # No match found - create new row
        new_row = create_shopify_row_from_square(square_row, @shopify_headers)

        output_rows << new_row

        handle = new_row['Token']
        # if handles.include? handle
        #   puts "Found matching handle when adding new row #{handle}"
        # end
        handles.add handle
        unmatched_count += 1
      else
        # Found matches
        duplicate_count += 1 if matches.size > 1

        if DEBUG == 1
          next if matches.none? { |m| m[:score] > 0.1 }

          puts 'Matches:'
          matches.sort_by { |match| -match[:score] }.first(4).each do |match|
            puts "  #{match[:score]}\t#{match[:row]['Title']} <> #{square_row['Item Name']}"
          end
        end

        match = matches.sort_by { |match| [-1*match[:score], match[:row]['Title']] }.first

        shopify_row = match[:row].dup
        confidence = calculate_confidence(shopify_row, square_row, match[:match_type])
        next if match[:score] < SIMILARITY_THRESHOLD

        # Add Square SKU to Variant SKU (append if already exists)
        if shopify_row['Variant SKU'].to_s.strip.empty?
          shopify_row['Variant SKU'] = square_row['SKU'] || ''
        # else
        #   existing_sku = shopify_row['Variant SKU']
        #   new_sku = square_row['SKU'] || ''
        #   shopify_row['Variant SKU'] = "#{existing_sku}, #{new_sku}".strip
        end
        shopify_row['Variant Barcode'] = shopify_row['Variant SKU']

        shopify_row['Match Confidence'] = confidence
        shopify_row['Match Notes'] = if matches.size > 1
                                       "Multiple matches found (#{matches.size} total)"
                                     else
                                       ''
                                     end
        shopify_row['Square Title'] = square_row['Item Name']

        handle = shopify_row['Handle']
        if handles.include? handle
          # puts "Found matching handle with existing row #{handle}"
          manual_intervention_rows << shopify_row
        else
          handles.add handle
          output_rows << shopify_row
        end

        matched_count += 1
        @matched_square_indices.add(square_idx)
      end

      puts "  Processed #{square_idx + 1}/#{@square_rows.size} Square rows..." if (square_idx + 1) % 100 == 0
    end

    #  Add unmatched Shopify rows (rows that weren't matched to any Square item)
    puts "\nAdding unmatched Shopify rows..."
    shopify_matched_indices = Set.new
    output_rows.each do |row|
      # Try to find the original Shopify row index
      @shopify_rows.each_with_index do |shopify_row, idx|
        next unless row['Title'] == shopify_row['Title'] &&
                    row['Vendor'] == shopify_row['Vendor'] &&
                    row['Product Category'] == shopify_row['Product Category']

        shopify_matched_indices.add(idx)
        break
      end
    end

    unmatched_square_rows = @square_rows.map.with_index do |row, idx|
      next if @matched_square_indices.include?(idx)
      row
    end.compact

    puts "Creating #{unmatched_square_rows.count} rows directly from square..."
    unmatched_square_rows.each do |row|
      new_row = create_shopify_row_from_square(row, @shopify_headers)
      output_rows << new_row
    end

    puts "Adding shopify no match #{@shopify_rows.count}..."
    @shopify_rows.each_with_index do |shopify_row, idx|
      next if shopify_matched_indices.include? idx

      new_row = shopify_row.dup
      new_row['Match Confidence'] = 'No Match'
      new_row['Match Notes'] = 'Shopify row with no Square match'
      output_rows << new_row
    end

    output_rows = output_rows.uniq { |row| row['Variant SKU'] }

    puts "\nWriting output..."
    write_output(output_rows, @output_file)

    puts "\nWriting intervention..."
    write_output(manual_intervention_rows, @intervention_file)

    puts "\n=== Summary ==="
    puts "Total output rows: #{output_rows.size}"
    puts "Square rows matched: #{matched_count}"
    puts "Square rows unmatched (new rows created): #{unmatched_count}"
    puts "Duplicate matches: #{duplicate_count}"
    puts "Output written to: #{@output_file}"
  end

  def write_output(rows, file)
    # Get all headers including new ones
    all_headers = @shopify_headers.dup

    extra_headers = ['Match Confidence' , 'Match Notes', 'Square Title', 'Square Token']
    all_headers = (all_headers + extra_headers).uniq
    all_headers.sort_by! do |h|
      case h.downcase
      when 'handle'
        0
      when 'title'
        10
      when 'square title'
        20
      when 'vendor'
        5
      when 'variant sku'
        30
      when 'sku'
        30
      when 'variant barcode'
        31
      when 'match notes'
        40
      when 'match confidence'
        42
      else
        100
      end
    end
    CSV.open(file, 'w', write_headers: true, headers: all_headers, encoding: 'UTF-8') do |csv|
      rows.sort_by{|r| [r['Vendor'].to_s, r['Title'].to_s] }.each do |row|
        csv << all_headers.map { |h| row[h] || '' }
      end
    end
  end
end

# Main execution

square_file = 'Square 2.17.26.csv'
shopify_file = 'Shopify 2.17.26x.csv'
output_file = 'merged_shopify.20260217.csv'

# square_file = 'Square 2_Charlie Wylie.csv'
# shopify_file = 'Shopify 2_Charlie Wylie.csv'
# output_file = 'merged_Charlie Wylie.csv'

# square_file = "square-sample.csv"
# shopify_file = "shopify-sample.csv"
# output_file = "merged_sampler.csv"

# shopify_file = 'Shopify product list.csv'
# square_file = 'Square product export 1.31.26.csv'
# output_file = "Merged product list #{Time.now.to_i}.csv"

matcher = ProductMatcher.new(shopify_file, square_file, output_file)
matcher.process

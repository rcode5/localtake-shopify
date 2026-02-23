#!/usr/bin/env ruby

require 'csv'

def normalize_for_matching(vendor_name)
  return '' if vendor_name.nil? || vendor_name.to_s.strip.empty?

  normalized = vendor_name.to_s.strip

  # Remove "- LT" or "Local Take -" or "Local Take," prefixes
  normalized = normalized.sub(/^- LT\s*/, '')
  normalized = normalized.sub(/^Local Take\s*[-,\s]+\s*/, '')
  normalized = normalized.sub(/\s*- LT\s*$/, '')

  normalized.strip
end

def remove_ws(vendor_name)
  return vendor_name if vendor_name.nil?
  return vendor_name if vendor_name =~ /doodles|grqp/i

  vendor_name.gsub(/\bWS\b/, '').strip
end

def normalize_for_comparison(vendor_name)
  normalized = normalize_for_matching(vendor_name)
  normalized = remove_ws(normalized)
  normalized.downcase.strip
end

# Extract vendors from Shopify CSV
shopify_vendors = Set.new
puts 'Reading Shopify vendors...'
CSV.foreach('Shopify product list.csv', headers: true, encoding: 'UTF-8') do |row|
  vendor = row['Vendor']
  shopify_vendors.add(vendor) if vendor && !vendor.to_s.strip.empty?
end
puts "Found #{shopify_vendors.size} unique Shopify vendors"

# Extract vendors from Square CSV (Categories column)
square_vendors = Set.new
puts 'Reading Square vendors from Categories column...'
CSV.foreach('Square product export 1.31.26.csv', headers: true, encoding: 'UTF-8') do |row|
  vendor = row['Categories']
  square_vendors.add(vendor) if vendor && !vendor.to_s.strip.empty?
end
puts "Found #{square_vendors.size} unique Square vendors"

# Build the mapping
puts "\nBuilding vendor mapping..."
mapping = {}

square_vendors.each do |square_vendor|
  next if square_vendor.nil? || square_vendor.to_s.strip.empty?

  # Skip vendors with "doodles" or "GRQP" - don't try to map them
  next if square_vendor =~ /doodles|grqp/i

  # Normalize the square vendor for matching
  normalized_square = normalize_for_comparison(square_vendor)

  # Try to find a matching Shopify vendor
  best_match = nil
  best_score = 0

  shopify_vendors.each do |shopify_vendor|
    next if shopify_vendor.nil? || shopify_vendor.to_s.strip.empty?

    normalized_shopify = normalize_for_comparison(shopify_vendor)

    # Exact match after normalization - highest priority
    if normalized_square == normalized_shopify
      best_match = shopify_vendor
      best_score = 100
      break
    end

    # Check if normalized square contains the shopify vendor (e.g., "Local Take, Trays4Us WS" contains "Trays4Us")
    # Or if square vendor ends with something that matches (e.g., "Ork Inc" should match "Ork")
    if normalized_square.include?(normalized_shopify) && normalized_shopify.length >= 3
      score = normalized_shopify.length
      # Bonus for word boundary matches (e.g., "ork" at start of "ork inc")
      score += 10 if normalized_square.start_with?(normalized_shopify + ' ') || normalized_square == normalized_shopify
      if score > best_score
        best_match = shopify_vendor
        best_score = score
      end
    end

    # Check if shopify contains square (reverse)
    next unless normalized_shopify.include?(normalized_square) && normalized_square.length >= 3

    score = normalized_square.length
    # Bonus for word boundary matches
    score += 10 if normalized_shopify.start_with?(normalized_square + ' ') || normalized_shopify == normalized_square
    if score > best_score
      best_match = shopify_vendor
      best_score = score
    end
  end

  # Only add to mapping if:
  # 1. We found a match
  # 2. The original values are different (don't map identical values)
  mapping[square_vendor] = best_match if best_match && square_vendor.strip != best_match.strip
end

# Output the mapping
output_file = 'square_to_shopify_vendor_map.rb'
File.open(output_file, 'w') do |f|
  f.puts '# Auto-generated vendor mapping from Square Categories to Shopify Vendors'
  f.puts "# Generated: #{Time.now}"
  f.puts ''
  f.puts 'SQUARE_VENDOR_TO_SHOPIFY_VENDOR_LOOKUP = {'
  mapping.sort.each do |square_vendor, shopify_vendor|
    # Escape quotes in vendor names
    square_escaped = square_vendor.gsub('"', '\\"')
    shopify_escaped = shopify_vendor.gsub('"', '\\"')
    f.puts "  \"#{square_escaped}\" => \"#{shopify_escaped}\","
  end
  f.puts '}.freeze'
end

puts "\nSQUARE_VENDOR_TO_SHOPIFY_VENDOR_LOOKUP = {"
mapping.sort.each do |square_vendor, shopify_vendor|
  puts "  \"#{square_vendor}\" => \"#{shopify_vendor}\","
end
puts '}'

puts "\nTotal mappings: #{mapping.size}"
puts "Mapping saved to: #{output_file}"

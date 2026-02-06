#!/usr/bin/env ruby

require 'csv'

# Read the Shopify CSV file
csv_filename = $ARGV[0]
rows = CSV.read(csv_filename, headers: true)
vendors = Set.new()
rows.each do |row|
  vendor = (row['Vendor'] || row['Reporting Category'] || "").strip
  vendors << vendor unless vendor.empty?
end
pp vendors.to_a.sort



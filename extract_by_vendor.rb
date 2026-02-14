#!/usr/bin/env ruby

require 'csv'

class NoMatches < StandardError; end

# Read the Shopify CSV file
csv_filename = $ARGV[0]
vendor_name = $ARGV[1]
new_file_name = csv_filename.split('.')[0] + '_' + vendor_name.split('.')[0] + '.csv'
rows = CSV.read(csv_filename, headers: true)
vendor_rows = []
vendor_name_matcher = vendor_name.to_s.strip.downcase
rows.each do |row|
  vendor_rows << row.to_h if row.to_s.strip.downcase.include? vendor_name_matcher
end
raise NoMatches, "Found no matches for #{vendor_name}" unless vendor_rows.count > 0

puts "Writing #{vendor_rows.count} rows to file #{new_file_name}"
CSV.open(new_file_name, 'w', headers: true) do |csv|
  csv << vendor_rows.first.keys
  vendor_rows.each do |row|
    csv << row
  end
end

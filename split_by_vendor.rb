#!/usr/bin/env ruby

require 'csv'

class NoMatches < StandardError; end

class Splitter
  attr_reader :file

  def initialize(file)
    @file = file
  end

  def call
    vendors.each do |vendor|
      vendor_data = extract_vendor_data(vendor)
      write_vendor_file(vendor_data, vendor)
    end
  end

  def extract_vendor_data(vendor)
    data.filter { |row| row['Vendor'] == vendor }
  end

  def write_vendor_file(vdata, vendor)
    fname = "20260222/#{generate_filename(vendor)}"
    CSV.open(fname, 'w') do |csv|
      headers = vdata.first.headers
      csv << headers
      vdata.each do |row|
        csv << row
      end
    end
    puts "Wrote #{vendor} data to #{fname}"
  end

  private

  def data
    @data ||= CSV.read(file, headers: true)
  end

  def vendors
    @vendors ||= data.map do |row|
      row['Vendor']
    end.uniq
  end

  def generate_filename(vendor)
    "merged-#{vendor.downcase.gsub(/\s+/, '-')}.csv"
  end
end

# # Read the Shopify CSV file
# csv_filename = $ARGV[0]
# vendor_name = $ARGV[1]
# new_file_name = csv_filename.split('.')[0] + '_' + vendor_name.split('.')[0] + '.csv'
# rows = CSV.read(csv_filename, headers: true)
# vendor_rows = []
# vendor_name_matcher = vendor_name.to_s.strip.downcase
# rows.each do |row|
#   vendor_rows << row.to_h if row.to_s.strip.downcase.include? vendor_name_matcher
# end
# raise NoMatches, "Found no matches for #{vendor_name}" unless vendor_rows.count > 0

# puts "Writing #{vendor_rows.count} rows to file #{new_file_name}"
# CSV.open(new_file_name, 'w', headers: true) do |csv|
#   csv << vendor_rows.first.keys
#   vendor_rows.each do |row|
#     csv << row
#   end
# end

puts "ARGS #{$ARGV[0]}"

Splitter.new($ARGV[0]).call

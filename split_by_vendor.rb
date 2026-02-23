#!/usr/bin/env ruby

require 'csv'
require 'optparse'
require 'fileutils'


class FileSplitter
  attr_reader :file, :prefix, :dir
  def initialize(file, prefix:, directory:)
    @file = file
    @prefix = prefix
    @dir = directory
  end

  def call
    ensure_directory!
    rows = load_file
    rows.group_by { |row| row['Vendor'] }.each do |vendor, rows|
      write_rows(vendor, rows)
    end
  end

  private

  def load_file
    CSV.read(file, headers: true).map(&:to_h)
  end

  def write_rows(vendor, rows)
    fname = generate_filename(vendor)
    puts "Writing #{rows.count} rows to #{fname} ..."
    CSV.open(fname, "w", write_headers: true, headers: rows.first.keys) do |csv|
      rows.each { csv << _1 }
    end
  end

  def generate_filename(vendor)
    File.join(dir, [
      prefix,
      vendor.gsub(/[[:punct:]]/, '-').gsub(/\s+/, '-').gsub(/--*/, '-').downcase + ".csv"
    ].join("-"))
  end

  def ensure_directory!
    FileUtils.mkdir_p(dir) unless dir.nil? || dir == ''
  end
end


options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("--prefix=PREFIX", "filenames prefix") do |prefix|
    options[:prefix] = prefix
  end
  opts.on("--dir=DIR", "directory to put everythings") do |dir|
    options[:dir] = dir
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end

parser.parse!
file = ARGV[0]

splitter = FileSplitter.new(file, prefix: options[:prefix], directory: options[:dir]).call


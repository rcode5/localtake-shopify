#!/usr/bin/env ruby

require './vendors'

removable = [
  '- LT',
  'Local Take -',
]

VENDOR_MAP = SQUARE_VENDORS.filter_map do |v|
  cleaned = v.dup
  removable.each do |to_remove|
    cleaned.sub!(to_remove, '')
  end
  cleaned.sub!(/\bWS\b/, '') if v !~ /doodles|grqp/i
  [v, cleaned.strip] if v != cleaned.strip
end.to_h.tap do |h|
  h['SF Candle'] = 'SF Candle Co'
  h['SF Candle Co'] = 'SF Candle Co'
  h['Amy Rose WS'] = 'Amy Rose WS'
  h['Amy Rose Moore'] = 'Amy Rose WS'
  h['Tickle & Smash'] = 'Tickle and Smash'
end.freeze

# pp VENDOR_MAP

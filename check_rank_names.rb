#!/usr/bin/env ruby

module Name
end
require_relative 'app/models/name/inferences.rb'
include Name::Inferences

suf = { family: 'aceae', order: 'ales', class: 'ia', phylum: 'ota' }

ARGF.each do |ln|
  row = ln.chomp.split("\t")
  rank = row[1].gsub(/Anomalous /, '')
  expected = row[4].gsub(/_[A-Z]+/, '')
  base = row[5].gsub(/From ([A-Za-z]+).*/, '\1')
  root = genus_root(base)
  suffix = suf[rank.to_sym]
  built = root + suffix
  unless built == expected
    puts "From file: #{expected}, inferred by Registry: #{built}"
  end
end


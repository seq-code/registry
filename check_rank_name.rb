#!/usr/bin/env ruby

module Name
end
require_relative 'app/models/name/inferences.rb'
include Name::Inferences

suf = { family: 'aceae', order: 'ales', class: 'ia', phylum: 'ota' }

ARGF.each do |ln|
  name = ln.chomp
  root = genus_root(name)
  suf.each { |rank, suffix| puts "#{rank}: #{root}#{suffix}" }
end


json.response do
  json.status 'ok'
  json.message_type 'genome'
end
json.partial! 'genomes/genome', genome: @genome

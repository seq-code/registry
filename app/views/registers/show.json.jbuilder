json.partial! 'registers/register', register: @register
json.names(@names, partial: 'names/type_genome', as: :name)


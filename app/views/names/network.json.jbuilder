json.nodes(@nodes, partial: 'names/network/node', as: :name)
json.links(@edges, partial: 'names/network/edge', as: :placement)


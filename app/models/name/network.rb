module Name::Network
  def network_nodes
    return @network_nodes unless @network_nodes.nil?

    @network_nodes = Set.new
    @network_edges = Set.new
    @network_nodes << self

    # Up
    @network_nodes += network_ancestors
    @network_edges += network_ancestor_edges

    # Down
    @network_nodes += network_descendents
    @network_edges += network_descendent_edges

    # Type
    if type_is_name?
      @network_nodes += type_name.network_nodes
      @network_edges << { source: id, target: type_name.id, kind: :is_type }
      @network_edges += type_name.network_edges
    end

    # Return
    @network_nodes
  end

  def network_edges
    network_nodes
    @network_edges
  end

  def network_ancestors
    return @network_ancestors unless @network_ancestors.nil?

    @network_ancestors = Set.new
    @network_ancestor_edges = Set.new
    placements.each do |placement|
      @network_ancestors << placement.parent
      @network_ancestors += placement.parent.network_ancestors
      @network_ancestor_edges << placement
      @network_ancestor_edges += placement.parent.network_ancestor_edges
    end
    @network_ancestors
  end

  def network_ancestor_edges
    @network_ancestor_edges
  end

  def network_descendents
    return @network_descendents unless @network_descendents.nil?

    @network_descendents = Set.new
    @network_descendent_edges = Set.new
    child_placements.each do |placement|
      @network_descendents << placement.name
      @network_descendent_edges << placement
    end
    @network_descendents
  end

  def network_descendent_edges
    @network_descendent_edges
  end
end

module Name::Network
  def network_nodes
    return @network_nodes unless @network_nodes.nil?

    @network_nodes = Set.new
    @network_edges = Set.new
    @network_nodes << self

    # Up
    @network_nodes += network_up_nodes
    @network_edges += network_up_edges

    # Down
    @network_nodes += network_down_nodes
    @network_edges += network_down_edges

    # Type
    @network_nodes += network_type_nodes
    @network_edges += network_type_edges

    # Other (already included) types
    @network_nodes.each do |i|
      next unless i.type_is_name?
      next unless @network_nodes.include? i.type_name

      @network_edges << { source: i.id, target: i.type_name.id, kind: :is_type }
    end

    # Return
    @network_nodes
  end

  def network_type_nodes
    return @network_type_nodes unless @network_type_nodes.nil?

    @network_type_nodes = Set.new
    @network_type_edges = Set.new
    return @network_type_nodes unless type_is_name?

    @network_type_nodes << type_name
    @network_type_nodes += type_name.network_up_nodes
    @network_type_nodes += type_name.network_type_nodes
    @network_type_edges << { source: id, target: type_name.id, kind: :is_type }
    @network_type_edges += type_name.network_up_edges
    @network_type_edges += type_name.network_type_edges
    @network_type_nodes
  end

  def network_type_edges
    network_type_nodes
    @network_type_edges
  end

  def network_edges
    network_nodes
    @network_edges
  end

  def network_up_nodes
    return @network_up_nodes unless @network_up_nodes.nil?

    @network_up_nodes = Set.new
    @network_up_edges = Set.new
    placements.includes(:parent, :name).each do |placement|
      next if placement.downwards?

      @network_up_nodes << placement.parent
      @network_up_nodes += placement.parent.network_up_nodes
      @network_up_edges << placement
      @network_up_edges += placement.parent.network_up_edges
    end
    @network_up_nodes
  end

  def network_up_edges
    network_up_nodes
    @network_up_edges
  end

  def network_down_nodes
    return @network_down_nodes unless @network_down_nodes.nil?

    @network_down_nodes = Set.new
    @network_down_edges = Set.new
    child_placements.includes(:parent, :name).each do |placement|
      next if placement.downwards?

      @network_down_nodes << placement.name
      @network_down_edges << placement
      @network_down_nodes += placement.name.network_up_nodes
      @network_down_edges += placement.name.network_up_edges
    end
    @network_down_nodes
  end

  def network_down_edges
    @network_down_edges
  end
end

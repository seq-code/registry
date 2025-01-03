module Name::Network
  def network_nodes
    return @network_nodes unless @network_nodes.nil?

    @network_nodes = Set.new
    @network_edges = Set.new
    @network_nodes << self

    # Up
    @network_nodes += network_up_nodes
    @network_edges += network_up_edges

    # Sides
    @network_nodes += network_side_nodes
    @network_edges += network_side_edges

    # Down
    @network_nodes += network_down_nodes
    @network_edges += network_down_edges

    # Type
    @network_nodes += network_type_nodes
    @network_edges += network_type_edges

    # Other (already included) types
    @network_nodes.each do |i|
      next unless i.is_a? Name
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

    if type_is_name?
      @network_type_nodes << type_name
      @network_type_nodes += type_name.network_up_nodes
      @network_type_nodes += type_name.network_type_nodes
      @network_type_edges << {
        source: id, target: type_name.id, kind: :is_type
      }
      @network_type_edges += type_name.network_up_edges
      @network_type_edges += type_name.network_type_edges
    elsif type?
      @network_type_nodes << nomenclatural_type
      nomenclatural_type.typified_names.each do |up_name|
        @network_type_nodes << up_name
        @network_type_nodes += up_name.network_up_nodes
        @network_type_edges += up_name.network_up_edges
        @network_type_edges << {
          source: up_name.id,
          target: nomenclatural_type.qualified_id,
          kind: :is_type
        }
      end
    end
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
      next if !placement.parent.present? || placement.downwards?

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

  def network_side_nodes
    return @network_side_nodes unless @network_side_nodes.nil?

    @network_side_nodes = Set.new
    @network_side_edges = Set.new
    if correct_name.present?
      @network_side_nodes << correct_name
      @network_side_nodes += correct_name.network_up_nodes
      @network_side_edges += correct_name.network_up_edges
      @network_side_edges << {
        source: id, target: correct_name.id, kind: :is_synonym
      }
    end

    synonyms.each do |synonym|
      @network_side_nodes << synonym
      @network_side_nodes += synonym.network_up_nodes
      @network_side_edges += synonym.network_up_edges
      @network_side_edges << {
        source: synonym.id, target: id, kind: :is_synonym
      }
    end

    @network_side_nodes
  end

  def network_side_edges
    network_side_nodes
    @network_side_edges
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

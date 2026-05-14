# frozen_string_literal: true

# Controller for network-related actions on names.
class Names::NetworkController < Names::BaseController
  # GET /names/1/network
  def network
    respond_to do |format|
      format.html
      format.json do
        @nodes = @name.network_nodes
        @edges = @name.network_edges
      end
    end
  end
end

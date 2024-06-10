
drag = simulation => {
  function dragstarted(event, d) {
    if (!event.active) simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
  }
  
  function dragged(event, d) {
    d.fx = event.x;
    d.fy = event.y;
  }
  
  function dragended(event, d) {
    if (!event.active) simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  }
  
  return d3.drag()
      .on("start", dragstarted)
      .on("drag", dragged)
      .on("end", dragended);
}

function taxonomic_network(id, container_id) {
  // Gather data
  const data_url = ROOT_PATH + "names/" + id + "/network.json";

  // Create container
  const width = 1024; // 928;
  const height = 600;
  $("#" + container_id).html('');
  const svg = d3.select("#" + container_id).append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", [-width / 2, -height / 2, width, height])
      .attr("style", "max-width: 100%; height: auto;");

  // Obtain data in JSON
  d3.json(data_url).then(function(data) {
    const ranks = {
      "domain":     { "col": "#13f", "k": 0 },
      "phylum":     { "col": "#33d", "k": 1 },
      "class":      { "col": "#53b", "k": 2 },
      "order":      { "col": "#739", "k": 3 },
      "family":     { "col": "#937", "k": 4 },
      "genus":      { "col": "#b35", "k": 5 },
      "species":    { "col": "#d33", "k": 6 },
      "subspecies": { "col": "#f31", "k": 7 },
    };

    const simulation =
      d3.forceSimulation(data.nodes)
        .force("link",
          d3.forceLink(data.links)
            .id(d => d.id)
            .distance(1)
            .strength(d => d.kind == "is_type" ? 0.1 : 1)
        )
        .force("x", d3.forceX().strength(0.1))
        .force("charge",
          d3.forceManyBody()
            .strength(-2500)
        )
        .force("y",
          d3.forceY(d => ranks[d.rank] ? (ranks[d.rank].k / 7 - 0.5) * height * 0.75 : null)
            .strength(1)
        );

    // Append links
    const link = svg.append("g")
        .selectAll("line")
        .data(data.links)
        .join("g");

    link.append("line")
          .attr("stroke-opacity", 0.7)
          .attr("stroke-width", 2.5)
          .attr("stroke", d => d.preferred ? "#000" : d.kind == "is_type" ? "#d33" : "#ccc")
          .attr("stroke-dasharray", d => d.kind == "is_type" ? "5,3" : null);

    link.insert("circle")
        .classed("gtdb", true)
        .attr("r", 4)
        .attr("fill", "#649964")
        .attr("opacity", d => d.gtdb_taxonomy ? 1 : 0);

    link.insert("circle")
        .classed("ncbi", true)
        .attr("r", 4)
        .attr("fill", "#266b99")
        .attr("opacity", d => d.ncbi_taxonomy ? 1 : 0);

    // Append nodes
    function showDetail(d, i) {
      d3.select(this.childNodes[1]).attr("opacity", 0.5);
    }
    function hideDetail(d, i) {
      d3.select(this.childNodes[1]).attr("opacity", 0);
    }
    function gotoNode(d, i) {
      taxonomic_network(i.id, container_id);
      $("h1.network-title > a").html(i.styling);
      $("h1.network-title > a").attr("href", i.url);
    }
    const node = svg.selectAll(".node")
      .data(data.nodes)
      .enter()
      .append("g")
      .classed("node", true)
      .call(drag(simulation))
      .on("mouseover", showDetail)
      .on("mouseout", hideDetail)
      .on("click", gotoNode);

    node.append("circle")
        .attr("stroke-width", 6)
        .attr("fill", d => ranks[d.rank] ? ranks[d.rank].col : "#fff")
        .attr("stroke", d => d.id == id ? "#000" : "#fff")
        .attr("r", 20);

    node.append("circle")
        .attr("stroke-width", 6)
        .attr("fill", "#fff")
        .attr("opacity", 0)
        .attr("r", 26);

    node.append("text")
        .attr("font-size", 14)
        .attr("font-weight", "bold")
        .attr("text-anchor", "middle")
        .attr("stroke-width", 2)
        .attr("stroke", "#fff")
      .text(d => d.name);

    node.append("text")
        .attr("font-size", 14)
        .attr("fill", "black")
        .attr("font-weight", "bold")
        .attr("text-anchor", "middle")
      .text(d => d.name);

    simulation.on("tick", () => {
      link
        .selectAll("line")
          .attr("x1", d => d.source.x)
          .attr("y1", d => d.source.y)
          .attr("x2", d => d.target.x)
          .attr("y2", d => d.target.y)
      link
        .selectAll("circle.gtdb")
          .attr("cx", d => (d.source.x*0.9 + d.target.x*1.1)/2)
          .attr("cy", d => (d.source.y*0.9 + d.target.y*1.1)/2);
      link
        .selectAll("circle.ncbi")
          .attr("cx", d => (d.source.x*1.1 + d.target.x*0.9)/2)
          .attr("cy", d => (d.source.y*1.1 + d.target.y*0.9)/2);
      node
          .attr("cx", d => d.x)
          .attr("cy", d => d.y)
          .attr("transform", d => `translate(${d.x}, ${d.y})`);
    });
  });
}

$(document).on("turbolinks:load", function() {
  $("[data-behavior='network']").each(function() {
    var cont = $(this);
    var id = cont.data("id");
    var cont_id = "network-" + id;
    cont.attr("id", cont_id);
    taxonomic_network(id, cont_id);
  });
});


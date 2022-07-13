library(rgexf)
library(igraph)

net <- readRDS("network_free.rds")

# Figuring out colors
nodetypes <- c(
  "orange"    = "organizer",
  "steelblue" = "chair",
  "green"     = "speaker"
)

names(nodetypes) <- adjustcolor(names(nodetypes), alpha.f = .5)

# Getting the same layout as in netplot
set.seed(9292)
lout <- layout_with_kk(net)

# Creating the gexf object
gf <- igraph.to.gexf(
  net,
  nodesVizAtt = list(
    position = cbind(lout, 0) * 10,
    size     = sqrt(degree(net))/10,
    color    = col2rgb(names(nodetypes)[V(net)$type + 1]) |>t()
    ),
  edgesVizAtt = list(
    size = V(net)$weight/10
  ))

# Plot it!
plot(
  gf,
  minEdgeWidth   = .005,
  maxEdgeWidth   = .05,
  nodeSizeFactor = .25,
  zoomLevel      = 2
  )

library(data.table)
library(Matrix)
library(igraph)
library(netplot)
library(rgexf)

# We will use the topics to color the graph!
metadata <- fread("paper.meta.data.csv", header = TRUE)

metadata_topics <- strsplit(metadata$Topics, "\n")

metadata_topics <- lapply(metadata_topics, \(kw) {
  gsub("^[^[:print:]]+|[^[:print:]]+$", "", kw) |> unique() |> tolower() |>
    gsub(pattern = "[[:blank:]]{2,}", replacement = " ", perl = TRUE) |>
    gsub(pattern = "[^[:alnum:][:blank:]]+", replacement = " ", perl = TRUE)
})

# Now, let's associate with color
metadata_topics <- lapply(seq_along(metadata_topics), \(i) {
  data.table(
    paper = metadata$Title[i],
    topic = metadata_topics[[i]]
  )
}) |> rbindlist()

# Processing edges -------------------------------------------------------------
affiliation <- fread("affiliation.csv")
edges <- as(as.matrix(affiliation[,-1]), "dgCMatrix")
rownames(edges) <- affiliation$V1

affiliation <- t(edges)

edges <- which(affiliation != 0, arr.ind = TRUE, useNames = TRUE) |>
  data.table()

edges[, paper_count := .N, by = "row"]
setorder(edges, paper_count)

edges[, name := rownames(affiliation)[row]]
edges[, paper := colnames(affiliation)[col]]
edges[, row := NULL]
edges[, col := NULL]

# Generating network
edgelist    <- merge(
  edges[, .(ego = name, s = paper)],
  edges[, .(alter = name, s = paper)], allow.cartesian = TRUE, all = TRUE
)

edgelist <- edgelist[, .(
  ego   = fifelse(ego > alter, ego, alter),
  alter = fifelse(ego > alter, alter, ego)
)]

edgelist <- edgelist[, .(weight = .N), by = .(ego, alter)]

edgelist <- edgelist[ego != alter] |> unique()

# Vertices ---------------------------------------------------------------------
vertices <- data.table(
  name = unique(rownames(affiliation))
)

# Assigning one topic to each author
vertex_topic <- merge(
  metadata_topics,
  edges, allow.cartesian = TRUE
  )

vertex_topic <- vertex_topic[, .(count = .N), by = .(topic, name)]
setorder(vertex_topic, name, -count)

vertex_topic[, rank := 1:.N, by = .(name)]
vertex_topic <- vertex_topic[rank == 1L]
vertex_topic[, count := NULL]
vertex_topic[, rank := NULL]

vertices <- merge(vertices, vertex_topic, all.x = TRUE, all.y = FALSE)

# Classifying papers according to theme ----------------------------------------
net <- graph_from_data_frame(edgelist, vertices, directed = FALSE)

V(net)$color <- colors(distinct = TRUE)[as.integer(as.factor(V(net)$topic))] |>
  adjustcolor(alpha.f = .8)

set.seed(8123)
net <- add_layout_(net, with_kk())

graphics.off()
png(filename = "coauthor.png", width = 1024 * 4, height = 1024 * 4, pointsize = 24)
nplot(
  net,
  layout = graph_attr(net, "layout"),
  vertex.size.range  = c(.01, .02)*.8,
  edge.width.range   = c(0.5, 2),
  vertex.label.range = c(20, 30)*.8,
  edge.line.breaks   = 10,
  vertex.nsides      = rep(20, vcount(net)),
  vertex.label.show  = 1,
  edge.width         = E(net)$weight,
  vertex.color       = V(net)$color
  )
dev.off()


gf <- igraph.to.gexf(
  net,
  nodesVizAtt = list(
    position = cbind(graph_attr(net, "layout"), 0),
    color    = col2rgb(V(net)$color) |> t(),
    size     = sqrt(degree(net) + 4)
  )
)

plot(
  gf,
  minEdgeWidth   = .005,
  maxEdgeWidth   = .05,
  nodeSizeFactor = .25,
  zoomLevel      = 0,
  dir            = "coauthor",
  graphFile      = "sunbelt2022_coauthor.gexf"
)


library(data.table)
library(igraph)
library(rgexf)
library(netplot)

metadata <- fread("paper.meta.data.csv", header = TRUE)

topics <- strsplit(metadata$Topics, "\n")

topics <- lapply(topics, \(kw) {
  gsub("^[^[:print:]]+|[^[:print:]]+$", "", kw) |> unique() |> tolower() |>
    gsub(pattern = "[[:blank:]]{2,}", replacement = " ", perl = TRUE) |>
    gsub(pattern = "[^[:alnum:][:blank:]]+", replacement = " ", perl = TRUE)
})

topics_rank <- topics |> unlist()
topics_rank <- data.table(
  topic = topics_rank
)[, .(count = .N), by = "topic"]

topics <- lapply(seq_along(topics), \(i) {
  data.table(p = i, kw = topics[[i]])
}) |> rbindlist()

topics <- topics[complete.cases(topics)]

topics_el <- merge(
  topics[, .(w1 = kw, p)],
  topics[, .(w2 = kw, p)], allow.cartesian = TRUE
)

topics_el <- topics_el[, .(
  w1 = fifelse(w1 > w2, w1, w2),
  w2 = fifelse(w1 > w2, w2, w1)
)][w1 > w2]

topics_el <- topics_el[, .(inters = .N), by = .(w1, w2)]

ntopics <- nrow(topics_rank)
topics_mat <- matrix(
  0L,
  nrow = ntopics, ncol = ntopics,
  dimnames = with(topics_rank, list(topic, topic))
)

# |A intersetct B| / (|A| + |B| - |A intersect B|)
topics_mat[as.matrix(topics_el[,-3])] <- topics_el$inters

topics_mat <- topics_mat/(matrix(
  topics_rank$count, byrow = TRUE, nrow = ntopics, ncol = ntopics
) + topics_rank$count - topics_mat)

# The individual sums
topics_mat[] <- as.integer(topics_mat > .3)

(topics_net <- graph_from_adjacency_matrix(topics_mat, mode = "undirected"))

# Coloring accordin gto communities
topics_cluster <- cluster_louvain(topics_net)
V(topics_net)$community <- membership(topics_cluster)
V(topics_net)$color     <- colors(distinct = TRUE)[V(topics_net)$community] |>
  adjustcolor(alpha.f = .8)

# Computing layout
set.seed(13331)
topics_net <- add_layout_(topics_net, with_kk())

saveRDS(topics_net, "topics.rds")

graphics.off()
png(filename = "topics.png", width = 1024, height = 1024, pointsize = 24)
nplot(
  topics_net,
  layout             = graph_attr(topics_net, "layout"),
  vertex.color       = V(topics_net)$color,
  vertex.size.range  = c(.025, .05)*1.5,
  edge.width.range   = c(0.25, 1) * 10,
  vertex.label.range = c(10, 15)*1.5,
  edge.line.breaks   = 10,
  vertex.nsides      = rep(20, vcount(topics_net)),
  vertex.label.show  = 1, 
  zero.margins       = FALSE,
  edge.color         = rep(adjustcolor("darkgray", alpha.f = .8), ecount(topics_net))
)
dev.off()

gf <- igraph.to.gexf(
  topics_net,
  nodesVizAtt = list(
    position = cbind(graph_attr(topics_net, "layout"), 0),
    color    = col2rgb(V(topics_net)$color) |> t(),
    size     = sqrt(degree(topics_net) + 1)
  )
)

plot(
  gf,
  minEdgeWidth   = .1,
  maxEdgeWidth   = 2,
  nodeSizeFactor = .5,
  zoomLevel      = 0,
  dir            = "topics",
  graphFile      = "sunbelt2022_topics.gexf"
)

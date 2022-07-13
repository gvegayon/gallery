library(data.table)
library(igraph)
library(rgexf)
library(netplot)

metadata <- fread("paper.meta.data.csv", header = TRUE)

keywords <- strsplit(metadata$Keywords, ",")

keywords <- lapply(keywords, \(kw) {
  gsub("^[^[:print:]]+|[^[:print:]]+$", "", kw) |> unique() |> tolower() |>
    gsub(pattern = "[[:blank:]]{2,}", replacement = " ", perl = TRUE) |>
    gsub(pattern = "[^[:alnum:][:blank:]]+", replacement = " ", perl = TRUE)
})

keywords_rank <- keywords |> unlist()
keywords_rank <- data.table(
  keyword = keywords_rank
)[, .(count = .N), by = "keyword"]

keywords <- lapply(seq_along(keywords), \(i) {
  data.table(p = i, kw = keywords[[i]])
}) |> rbindlist()

keywords_el <- merge(
  keywords[, .(w1 = kw, p)],
  keywords[, .(w2 = kw, p)], allow.cartesian = TRUE
)

keywords_el <- keywords_el[, .(
  w1 = fifelse(w1 > w2, w1, w2),
  w2 = fifelse(w1 > w2, w2, w1)
)][w1 > w2]

keywords_el <- keywords_el[, .(inters = .N), by = .(w1, w2)]

nkeywords <- nrow(keywords_rank)
keywords_mat <- matrix(
  0L,
  nrow = nkeywords, ncol = nkeywords,
  dimnames = with(keywords_rank, list(keyword, keyword))
)

# |A intersetct B| / (|A| + |B| - |A intersect B|)
keywords_mat[as.matrix(keywords_el[,-3])] <- keywords_el$inters

keywords_mat <- keywords_mat/(matrix(
  keywords_rank$count, byrow = TRUE, nrow = nkeywords, ncol = nkeywords
) + keywords_rank$count - keywords_mat)

# The individual sums
keywords_mat[] <- as.integer(keywords_mat > .3)

(keyword_net <- graph_from_adjacency_matrix(keywords_mat, mode = "undirected"))

keyword_net_3 <- induced_subgraph(keyword_net, which(degree(keyword_net) > 3))

# Coloring accordin gto communities
keyword_cluster3 <- cluster_louvain(keyword_net_3)
V(keyword_net_3)$community <- membership(keyword_cluster3)
V(keyword_net_3)$color     <- colors(distinct = TRUE)[V(keyword_net_3)$community] |>
  adjustcolor(alpha.f = .8)

# Computing layout
set.seed(13331)
keyword_net_3 <- add_layout_(keyword_net_3, with_kk())

saveRDS(keyword_net_3, "keywords.rds")

graphics.off()
png(filename = "keywords.png", width = 1024 * 5, height = 1024 * 5, pointsize = 24)
nplot(
  keyword_net_3,
  layout             = graph_attr(keyword_net_3, "layout"),
  vertex.color       = V(keyword_net_3)$color,
  vertex.size.range  = c(.005, .01),
  edge.width.range   = c(0.25, 1),
  vertex.label.range = c(10, 20),
  edge.line.breaks   = 10,
  vertex.nsides      = rep(20, vcount(keyword_net_3)),
  vertex.label.show  = 1
)
dev.off()

gf <- igraph.to.gexf(
  keyword_net_3,
  nodesVizAtt = list(
    position = cbind(graph_attr(keyword_net_3, "layout"), 0),
    color    = col2rgb(V(keyword_net_3)$color) |> t(),
    size     = sqrt(degree(keyword_net_3) + 1)
  )
)

plot(
  gf,
  minEdgeWidth   = .005,
  maxEdgeWidth   = .05,
  nodeSizeFactor = .1,
  zoomLevel      = 1,
  dir            = "keywords",
  graphFile      = "sunbelt2022_keywords.gexf"
)

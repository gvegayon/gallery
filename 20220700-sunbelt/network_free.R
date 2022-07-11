library(data.table)
library(igraph)
library(netplot)

agenda <- fread("agenda_data.csv")

# Preparing the data -----------------------------------------------------------

# Organizers
organizers <- strsplit(agenda$organizers, split = "(\\s*,\\s*|\\s+and\\s+|\\s+/\\s+)") 

organizers <- data.table(
  name    = unlist(organizers),
  session = rep(agenda$session_id, sapply(organizers, length)),
  type    = 0L
)

# Chairs
chairs <- strsplit(agenda$chairs, split = "(\\s*,\\s*|\\s+and\\s+|\\s+/\\s+)") 

chairs <- data.table(
  name    = unlist(chairs),
  session = rep(agenda$session_id, sapply(chairs, length)),
  type    = 1L
)

# Speakers
speakers <- strsplit(agenda$speaker, split = "\\s*,\\s*") 

speakers <- data.table(
  name    = unlist(speakers),
  session = rep(agenda$session_id, sapply(speakers, length)),
  type    = 2L
)

all_relations <- rbind(chairs, organizers, speakers)
all_relations[, virtual := grepl("virtual|online", name, ignore.case = TRUE)]
all_relations[, name := gsub("\\([^)]*\\)", "", name)]
all_relations[, name := trimws(name, "both")]

# Preparing the network data----------------------------------------------------
vertices <- all_relations[, .(virtual = min(virtual), type = min(type)), by = "name"]

edges    <- merge(
  all_relations[, .(ego = name, s = session)],
  all_relations[, .(alter = name, s = session)], allow.cartesian = TRUE, all = TRUE
)

edges <- edges[, .(
  ego   = fifelse(ego > alter, ego, alter),
  alter = fifelse(ego > alter, alter, ego)
  )]

edges <- edges[, .(weight = .N), by = .(ego, alter)]

edges <- edges[ego != alter]

# Creating the network using igraph
net <- graph_from_data_frame(edges, vertices = vertices, directed = FALSE)

# Types
nodetypes <- c(
  "orange"    = "organizer",
  "steelblue" = "chair",
  "green"     = "speaker"
  )

names(nodetypes) <- adjustcolor(names(nodetypes), alpha.f = .5)

labs <- rank(-degree(net, mode = "in"), ties.method = "random")
labs <- ifelse(labs <= 200, V(net)$name, "")

set.seed(9292)
lout <- layout_with_kk(net)

graphics.off()
png(filename = "network_free_w_legend.png", width = 1024 * 3, height = 1024 * 3, pointsize = 24)

np <- nplot(
  net,
  edge.width         = V(net)$weight,
  vertex.color       = names(nodetypes)[V(net)$type + 1],
  layout             = lout,
  # bg.col             = "black",
  # vertex.label.col   = "white",
  vertex.size.range  = c(.005, .03),
  vertex.label       = labs,
  vertex.label.range = c(15, 20),
  vertex.nsides      = rep(20, vcount(net)),
  edge.width.range   = c(1, 5),
  edge.line.breaks = 10
  )
nplot_legend(np, labels = nodetypes, gp = gpar(fill = names(nodetypes)), pch = c(21, 21, 21))
# print(np)
dev.off()

graphics.off()
png(filename = "network_free.png", width = 1024 * 3, height = 1024 * 3, pointsize = 24)

np <- nplot(
  net,
  edge.width         = V(net)$weight,
  vertex.color       = names(nodetypes)[V(net)$type + 1],
  layout             = lout,
  bg.col             = "black",
  vertex.label.col   = "white",
  vertex.size.range  = c(.005, .03),
  vertex.label       = labs,
  vertex.label.range = c(15, 20),
  vertex.nsides      = rep(20, vcount(net)),
  edge.width.range   = c(1, 5),
  edge.line.breaks = 10
)
print(np)
dev.off()



saveRDS(net, file = "network_free.rds")

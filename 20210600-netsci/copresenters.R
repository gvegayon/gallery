library(igraph)
library(netplot)
library(data.table)

talks <- data.table::fread(
  "20210600-netsci/Networks 2021_ Main Conference Contributions Schedule - May 24 - FINAL PRESENTATION SCHEDULE - May 24.csv",
  skip = 8 
  )

# Generating list of authors
authors <- strsplit(talks$`Full Author Listing`, "\\s*,\\s*")

authors <- data.table(
  author  = unlist(authors),
  confid  = rep.int(talks$`Open Conf ID`, sapply(authors, length)),
  session = rep.int(talks$`Session Name`, sapply(authors, length))
)

# Ranking
author_rank <- as.data.frame(
  table(authors$author, dnn = list("Name")),
  responseName = "N"
  )

author_rank <- author_rank[order(-author_rank$N),,drop=FALSE]

# Co-authorship network --------------------------------------------------------
edgelist <- merge(authors, authors, by = "confid", allow.cartesian = TRUE)
edgelist <- edgelist[author.x != author.y]
edgelist <- edgelist[, list(author.x, author.y)]

# Sorting
ord <- edgelist[,1] > edgelist[,2]
edgelist <- cbind(
  ego   = ifelse(ord, edgelist$author.x, edgelist$author.y),
  alter = ifelse(ord, edgelist$author.y, edgelist$author.x)
)

edgelist <- unique(edgelist)

net <- graph_from_edgelist(edgelist, directed = FALSE)

lout <- layout_with_kk(net)
# set.seed(322)
# lout[] <- jitter(lout[], factor = 5) 

# Coloring
authors_profiles <- authors[, list(author, session)]
authors_profiles[, session := rep(names(which.max(table(session))), .N), by = author]
authors_profiles <- unique(authors_profiles)
mods <- merge(data.frame(author = V(net)$name), authors_profiles, all.x = TRUE, all.y = FALSE)

# We are only coloring the top sessions
top_sessions <- data.table(`Session Name` = mods$session)
top_sessions <- top_sessions[, .(nauths = .N), by = "Session Name"]
top_sessions[, pos := rank(-nauths, ties.method = "random")]
setorder(top_sessions, pos)
top_sessions[, accum := cumsum(nauths)]
top_sessions[, pcent := cumsum(nauths)/sum(nauths)]
top_sessions <- top_sessions[pcent <= .9]

mods[!mods$session %in% top_sessions$`Session Name`, "session"] <- "Other"

mods <- as.integer(as.factor(mods$session))

# Who to label
set.seed(3223)
labs <- rank(-degree(net, mode = "in"), ties.method = "random")
labs <- ifelse(labs <= 200, V(net)$name, "")

graphics.off()
png(filename = "20210600-netsci/copresenters.png", width = 1024 * 3, height = 1024 * 3, pointsize = 24)
net_grob <- nplot(
  net,
  edge.line.breaks   = 5,
  edge.curvature     = pi/6,
  vertex.nsides      = 15,
  layout             = lout, 
  vertex.size        = degree(net, mode = "out"),
  sample.edges       = .75, # Subsetting edges to avoid too much of a hairball
  vertex.size.range = c(.005, .03),
  vertex.label.show  = 1,
  vertex.label       = labs,
  vertex.label.range = c(15, 20),
  vertex.color       = grDevices::topo.colors(length(unique(mods)), alpha = .8)[mods],
  bg.col             = "black",
  vertex.label.col   = "white",
  edge.width.range   = c(1, 1) # All are the same
  )

# Netplot objects need to be printed!
print(net_grob)
dev.off()
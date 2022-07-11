library(stringr)
library(data.table)
library(netplot)

# Reading the data
dat <- readLines("agenda.txt")

# Grouping by sessions
sessions <- which(grepl("^[^[:alnum:]]*Session[\\s\\n]+[0-9]+", dat, perl = TRUE))

n_sessions <- length(sessions)

sessions <- cbind(
  start = sessions,
  end   = c(sessions[-1] - 1, length(dat))
)

sessions <- lapply(seq_len(n_sessions), \(s) {
  dat[sessions[s,1]:sessions[s,2]]
})

# Regular expression to catch title and speaker
regex_timedate <- "([0-9]+:[0-9]+[\\s\\n]*[APM]{2})[^0-9]+([0-9]+:[0-9]+[\\s\\n]*[APM]{2})[^a-zA-Z]+([a-zA-Z]+[\\s\\n]*[0-9]+)"
regex <- "Presentation[\\s\\n]+([0-9]+)[.]([^\\]]+)[\\s\\n]*\\[Speaker:[\\s\\n]*([^]]+)[^0-9]+"
regex <- paste0(regex, regex_timedate)

# For testing
if (FALSE) {
  matches <-dat |> paste(collapse = " ") |> str_match_all(pattern = regex)
  matches[[1]] |> View()
}

# Parsing each session
talks <- parallel::mclapply(sessions, \(S) {
  str_match_all(paste(S, collapse = " "), pattern = regex)[[1L]]
}, mc.cores = 4L)

sapply(talks, nrow) |> sum()

# Regular expression to catch session information ------------------------------
session_id <- parallel::mclapply(sessions, \(S) {
  s <- str_match(S, "^[^[:alnum:]]*Session[\\s\\n]+([0-9-]+)\\.[\\s\\n]*(.+)")
  rbind(s[!is.na(s)][2:3])
}, mc.cores = 4L)

chairs <- parallel::mclapply(sessions, \(S) {
  s <- str_match(S, "^[^C]*Chair:\\s(.+)")
  s[!is.na(s)][2]
}, mc.cores = 4L) |> unlist()

organizers <- parallel::mclapply(sessions, \(S) {
  s <- str_match(S, "Session[\\s\\n]*Organiser\\(s\\):\\s(.+)")
  s[!is.na(s)][2]
}, mc.cores = 4L) |> unlist()

ntalks <- parallel::mclapply(sessions, \(S) {
  s <- str_match(S, "^[^0-9]*([0-9]+)[\\s\\n]Subsessions")
  s[!is.na(s)][2]
}, mc.cores = 4L) |> unlist() |> as.integer()

sum(ntalks, na.rm = TRUE)

# Putting all together
final_db <- Map(\(session_, talks_, chairs_, org_, n_) {
  data.table(
    session_,
    chairs_, org_, n_,
    talks_[,-1,drop=FALSE]
  )
}, session_ = session_id, talks_ = talks, chairs_ = chairs, org_ = organizers, n_ = ntalks) |>
  rbindlist()

final_db <- setNames(
  final_db,
  c("session_id", "session_title", "chairs", "organizers", "ntalks", "presentation_num", "title", "speaker", "start", "end", "date")
  )

fwrite(final_db, "agenda_data.csv")

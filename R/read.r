#' Read Draftkings
#'
#' Reads in raw file and then cleans it up
#' @param path path to csv file
#' @export
read_dk <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  # check column headers
  headers <- c("Position", "Name + ID", "Name", "ID","Roster Position",
               "Salary", "Game Info","TeamAbbrev","AvgPointsPerGame")
  assert_has_cols(df, headers)
  df <- df[headers]

  # rename headers
  new_headers <- trimws(tolower(headers))
  new_headers <- gsub(" \\+ | ", "_", new_headers)
  colnames(df) <- new_headers

  # add opposing team
  df <- add_dk_opp_team(df)

  # trim whitespace (this also makes each column a character vector)
  df[] <- lapply(df, trimws)

  # fix column types
  df[["id"]] <- as.character(df[["id"]])
  df[["salary"]] <- as.integer(df[["salary"]])
  df[["avgpointspergame"]] <- as.double(df[["avgpointspergame"]])

  # select columns for model
  df_model <- df[c("id", "name", "teamabbrev", "opp_team", "location",
                   "roster_position", "salary", "avgpointspergame")]
  colnames(df_model) <- c("player_id", "player", "team", "opp_team", "location",
                          "position", "salary", "fpts_avg")

  # split positions for players that can play multiple, ex. 1B/3B -> c("1B", "3B")
  df_model[["position"]] <- strsplit(df_model[["position"]], "/")

  # expand multiple position players
  df_tidy <- unnest_col(df_model, "position")

  # filer FLEX and UTIL positions
  df_tidy <- df_tidy[!grepl("FLEX|UTIL", df_tidy[["position"]]),]

  # add row id
  df_tidy <- add_row_id(df_tidy)

  # tibble
  tibble::as_tibble(df_tidy)
}

#' Read Fanduel Players
#'
#' Expects a csv from \url{https://www.fanduel.com/} obtained by clicking
#' "Download Players List" for your contest page.
#'
#' @param path path to csv file
#' @export
read_fd <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  # keep only first columns
  df <- df[1:12]

  # check column headers
  headers <- c("Id","Position","First Name","Nickname","Last Name","FPPG",
               "Played","Salary","Game","Team","Opponent","Injury Indicator")
  assert_has_cols(df, headers)
  df <- df[headers]

  # extract location
  locations <- parse_locations(df[["Game"]])
  df[["location"]] <- locations[,3]

  # select columns
  df_tidy <- df[c("Id", "Nickname", "Team", "Opponent", "location", "Position",
                  "Salary", "FPPG", "Injury Indicator")]
  colnames(df_tidy) <- c("player_id", "player", "team", "opp_team", "location",
                         "position", "salary", "fpts_avg", "injury")

  # fix injury NAs
  df_tidy[["injury"]] <- with(df_tidy, ifelse(nchar(injury) == 0, NA_character_, injury))

  # add row ids
  df_tidy <- add_row_id(df_tidy)

  # tibble
  tibble::as_tibble(df_tidy)
}


#' Add a row id column to the data frame
#'
#' @param df data frame
#' @keywords internal
add_row_id <- function(df) {
  row.names(df) <- NULL
  orig_colnames <- colnames(df)
  df[["row_id"]] <- seq_len(nrow(df))
  df[c("row_id", orig_colnames)]
}

#' Add opposing team
#' @keywords internal
add_dk_opp_team <- function(df) {
  game_info <- unique(df[["game_info"]])
  regs <- parse_locations(game_info)

  away_team <- regs[,2]
  home_team <- regs[,3]

  teams <- data.frame(
    team = c(away_team, home_team),
    opp_team = c(home_team, away_team),
    location = rep(home_team, 2),
    stringsAsFactors = FALSE)

  merge(df, teams, by.x = "teamabbrev", by.y = "team")
}

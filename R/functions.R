
# TARGET FUNCTIONS --------------------------------------------------------

make_model_spatial_lag <- function(model_data, model_lm_multivariate, model_spatial_weights){
  
  model_data <- model_data |> 
    drop_na()
  
  model_spatial_lag <- lagsarlm(
    formula = model_lm_multivariate, 
    data = model_data, 
    listw = model_spatial_weights,
    zero.policy = TRUE
  )
  
  return(model_spatial_lag)
}

make_model_spatial_weights <- function(model_data){
  
  model_data <- model_data |> 
    drop_na()
  
  model_spatial_weights <- model_data |>  
    poly2nb()  |> 
    nb2listw(zero.policy = TRUE)
  
  return(model_spatial_weights)
}

make_model_lm_multivariate <- function(model_data){
  
  model_data <- model_data |> 
    drop_na()
  
  model_lm_multivariate <- lm(vote_no_pct ~ hh_vmt + vote_rep_pct, 
                 data = model_data)
  
  return(model_lm_multivariate)
}

make_model_lm_univariate <- function(model_data){
  
  model_data <- model_data |> 
    drop_na()
  
  model_lm_univariate <- lm(vote_no_pct ~ hh_vmt, 
                          data = model_data)
  
  return(model_lm_univariate)
}

make_model_data_i1631 <- function(hh_vmt_2012_2016, tracts_vote_2018){
  
  model_data_i1631 <- left_join(tracts_vote_2018, 
                          hh_vmt_2012_2016,
                          by = join_by(geoid)) |> 
    transmute(
      geoid,
      hh_vmt,
      vote_rep_pct = vote_rep_pct * 100,
      vote_i1631n_pct = vote_i1631n_pct * 100,
      vote_no_pct = vote_i1631n_pct) |> 
    st_sf()
  
  return(model_data_i1631)
}

make_model_data_i732 <- function(hh_vmt_2012_2016, tracts_vote_2016){
  
  model_data_i732 <- left_join(tracts_vote_2016, 
                          hh_vmt_2012_2016,
                          by = join_by(geoid)) |> 
    transmute(
      geoid,
      hh_vmt,
      vote_rep_pct = vote_rep_pct * 100,
      vote_i0732n_pct = vote_i0732n_pct * 100,
      vote_no_pct = vote_i0732n_pct) |> 
    st_sf()
  
  return(model_data_i732)
}

make_tracts_vote_2018 <- function(wa_pop_2020,
                                  vote_us_senator_2018, 
                                  i1631,
                                  tracts
){
  
  
  vote_2018 <- inner_join(vote_us_senator_2018,
                         st_drop_geometry(i1631))
  
  tracts_vote_2018 <- interpolate_pw(
    from = vote_2018,
    to = tracts,
    to_id = "geoid",
    extensive = TRUE,
    weights = wa_pop_2020,
    weight_column = "pop_2020",
    crs = 6152) |> 
    rowwise() |> 
    mutate(
      vote_rep_pct = vote_us_senator_2018_rep / sum(c_across(starts_with("vote_us_senator")), na.rm = TRUE),
      vote_i1631n_pct = i1631_no / sum(i1631_no, i1631_yes, na.rm = TRUE)
    )
  
  
  return(tracts_vote_2018)
}

make_tracts_vote_2016 <- function(wa_pop_2020,
                                  vote_pres_2016, 
                                  i732,
                                  tracts
){
  
  vote_2016 <- full_join(vote_pres_2016,
                         st_drop_geometry(i732))
  
  tracts_vote_2016 <- interpolate_pw(
    from = vote_2016,
    to = tracts,
    to_id = "geoid",
    extensive = TRUE,
    weights = wa_pop_2020,
    weight_column = "pop_2020",
    crs = 6152) |> 
    rowwise() |> 
    mutate(
      vote_rep_pct = g16prstrum / sum(c_across(starts_with("g16prs")), na.rm = TRUE),
      vote_i0732n_pct = g16i0732n / sum(g16i0732n, g16i0732y, na.rm = TRUE)
    )
    
  
  return(tracts_vote_2016)
}

make_wa_pop_2020 <- function(){
  
  wa_county_geoids <- tidycensus::county_laea$GEOID |> 
    keep(~ str_detect(.x,"^53")) |> 
    map_chr(~str_remove(.x,"^53"))
  
  wa_pop_2020 <- get_decennial(geography = "block",
                               output = "wide",
                               variables = "P1_001N",
                               year = 2020,
                               state = "WA",
                               county = wa_county_geoids, 
                               geometry = TRUE) |> 
    clean_names() |>  
    to_proj_crs() |> 
    st_make_valid() |> 
    transmute(geoid,
              pop_2020 = as.integer(p1_001n)) 
  
  return(wa_pop_2020)
}



make_wa_pop_2010 <- function(){
  
  wa_county_geoids <- tidycensus::county_laea$GEOID |> 
    keep(~ str_detect(.x,"^53")) |> 
    map_chr(~str_remove(.x,"^53"))
  
  wa_pop_2010 <- get_decennial(geography = "block",
                               output = "wide",
                               variables = "P001001",
                               year = 2010,
                               state = "WA",
                               county = wa_county_geoids, 
                               geometry = TRUE) |> 
    clean_names() |>  
    to_proj_crs() |> 
    st_make_valid() |>
    transmute(geoid,
              pop_2010 = as.integer(p001001)) 
  
  return(wa_pop_2010)
}


make_wa_blocks <- function(){
  
  wa_county_geoids <- tidycensus::county_laea$GEOID |> 
    keep(~ str_detect(.x,"^53")) |> 
    map_chr(~str_remove(.x,"^53"))
  
  
  wa_blocks <- tigris::blocks(state = "wa",
                              year = 2020,
                              county = wa_county_geoids) |> 
    clean_names() |> 
    to_proj_crs() |> 
    st_make_valid()
  
  return(wa_blocks)
  
}

make_tracts <- function(){
  
  tracts <- tigris::tracts(state = "WA",
                           year = 2016,
                           cb = TRUE) |> 
    to_proj_crs() |> 
    clean_names() |> 
    st_make_valid()
  
  return(tracts)
}

make_senate_dist_2016 <- function(file_senate_dist_2016){
  # source: https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2016&layergroup=State+Legislative+Districts
  
  senate_dist_2016 <- st_read(sprintf("/vsizip/%s", file_senate_dist_2016)) |> 
    to_proj_crs() |> 
    clean_names() |> 
    st_make_valid()
    
  return(senate_dist_2016)
}

make_hh_vmt_2012_2016 <- function(latch_fp){
  
  hh_vmt_2012_2016 <- read_csv(latch_fp) |> 
    clean_names() |> 
    select(geoid = geocode,
           hh_vmt = est_vmiles,
           contains("flag_"))
  
  return(hh_vmt_2012_2016)
  
  
}

make_i1631 <- function(elec_url,
                       prec_fp,
                       kc_prec_fp){
  
  # 2018 Election Results 
  
  elec_2018 <- read_csv(elec_url) |> 
    clean_names() |> 
    filter(str_detect(race, "1631")) |> 
    pivot_wider(names_from = "candidate",values_from = "votes") |> 
    rename(i1631_yes = Yes,
           i1631_no = No) |> 
    select(county_code,
           precinct_code,
           i1631_yes,
           i1631_no) |> 
    filter(!precinct_code == -1) |>  # -1 is used for the county total
    mutate(precinct_code = case_when(  # fix Kitsap's precinct codes
      county_code %in% "KP" ~ precinct_code-100000,
      TRUE ~ precinct_code
    )) |> 
    mutate(precinct_code = as.character(precinct_code)) |> 
    mutate(full_prc = str_c(county_code,
                            str_pad(precinct_code,
                                    width = 8,
                                    side = "left",
                                    pad = "0"))) |> 
    select(-precinct_code,-county_code)
  
  elec_king_county_2018 <- read_csv(kc_prec_fp) |> 
    clean_names() |> 
    filter(str_detect(race, "1631")) |> 
    filter(counter_type %in% c("Yes","No")) |> 
    pivot_wider(names_from = "counter_type",values_from = "sum_of_count") |> 
    transmute(full_prc = str_c("KI", 
                               str_pad(str_extract(precinct,".{4}$"),
                                       width = 8,
                                       side = "left",
                                       pad = "0")),
              i1631_yes = Yes,
              i1631_no = No
    )
  
  elec_2018 <- bind_rows(elec_2018,elec_king_county_2018)
  
  # 2018 Election Precincts  
  
  prec_2018 <- st_read(sprintf("/vsizip/%s", prec_fp),
                       layer = "2018Precincts_VERIFIED") |> 
    to_proj_crs() |> 
    clean_names() |> 
    st_make_valid()
  
  
  # Join 
  
  i1631 <- prec_2018 |>
    left_join(elec_2018)
  
  # Note: 
  # There are more precincts (7,336)
  # than there are precinct election results for I-1631 (7264)
  
  list(prec_2018, elec_2018) |> 
    map(nrow)
  
  return(i1631)
}

make_vote_us_senator_2018 <- function(elec_url, 
                                      prec_fp,
                                      kc_prec_fp){
  
  # 2018 Election Results 
  
  elec_2018 <- read_csv(elec_url) |> 
    clean_names() |> 
    filter(str_detect(race, "U.S. Senator")) |> 
    pivot_wider(names_from = "candidate",values_from = "votes") |> 
    clean_names() |> 
    rename(vote_us_senator_2018_dem = maria_cantwell,
           vote_us_senator_2018_rep = susan_hutchison) |> 
    select(county_code,
           precinct_code,
           vote_us_senator_2018_dem,
           vote_us_senator_2018_rep) |> 
    filter(!precinct_code == -1) |>  # -1 is used for the county total
    mutate(precinct_code = case_when(  # fix Kitsap's precinct codes
      county_code %in% "KP" ~ precinct_code-100000,
      TRUE ~ precinct_code
    )) |> 
    mutate(precinct_code = as.character(precinct_code)) |> 
    mutate(full_prc = str_c(county_code,
                            str_pad(precinct_code,
                                    width = 8,
                                    side = "left",
                                    pad = "0"))) |> 
    select(-precinct_code,-county_code)
  
  elec_king_county_2018 <- read_csv(kc_prec_fp) |> 
    clean_names() |> 
    filter(str_detect(race, "US Senator")) |> 
    filter(party %in% c("Dem","Rep")) |> 
    select(precinct, party, sum_of_count) |> 
    pivot_wider(names_from = "party",values_from = "sum_of_count") |> 
    transmute(full_prc = str_c("KI", 
                               str_pad(str_extract(precinct,".{4}$"),
                                       width = 8,
                                       side = "left",
                                       pad = "0")),
              vote_us_senator_2018_dem = Dem,
              vote_us_senator_2018_rep = Rep
    )
  
  elec_2018 <- bind_rows(elec_2018, elec_king_county_2018)
  
  # 2018 Election Precincts  
  
  prec_2018 <- st_read(sprintf("/vsizip/%s", prec_fp),
                       layer = "2018Precincts_VERIFIED") |> 
    to_proj_crs() |> 
    clean_names() |> 
    st_make_valid()
  
  
  # Join 
  
  vote_us_senator_2018 <- prec_2018 |>
    left_join(elec_2018)
  
  # Note: 
  # There are substantially more precincts (7,336)
  # than there are precinct election results for I-1631 (4460)
  
  list(prec_2018, elec_2018) |> 
    map(nrow)
  
  return(vote_us_senator_2018)
}

make_i732 <- function(prec_fp, elec_fp){
  
  # Precincts (2016) 
  
  prec_2016 <- st_read(sprintf("/vsizip/%s", prec_fp),
                       layer = "Statewide_Prec_2016") |> 
    to_proj_crs() |> 
    clean_names() |> 
    st_make_valid()
  
  # 2016 Election results
  
  temp_dir <- tempdir()
  
  xlsx_fp <- "2016-general-data/2016Gen_Precinct_Results_GIS-Ready.xlsx"
  
  unzip(elec_fp, 
        files = xlsx_fp, 
        exdir = temp_dir)
  
  elec_2016 <- read_excel(file.path(temp_dir, xlsx_fp)) |> 
    clean_names() |> 
    select(precinct_code,
           contains("i0732"))
  
  # Join
  
  i732 <- prec_2016 |> 
    select(county, 
           preccode, 
           precname,
           precinct_code = st_code) |> 
    left_join(elec_2016, by = "precinct_code") |> 
    mutate(preccode = as.character(preccode))
  
  
  return(i732)
}

make_vote_pres_2016 <- function(prec_fp, elec_fp){
  
  # prec_fp <- here("data/Statewide_Prec_2016.zip")
  # 
  # elec_fp <- here("data/2016-general-data.zip")
  
  
  # Precincts (2016) 
  
  prec_2016 <- st_read(sprintf("/vsizip/%s", prec_fp),
                       layer = "Statewide_Prec_2016") |> 
    to_proj_crs() |> 
    clean_names() |> 
    st_make_valid()
  
  # 2016 Election results
  
  temp_dir <- tempdir()
  
  xlsx_fp <- "2016-general-data/2016Gen_Precinct_Results_GIS-Ready.xlsx"
  
  unzip(elec_fp, 
        files = xlsx_fp, 
        exdir = temp_dir)
  
  elec_2016 <- read_excel(file.path(temp_dir, xlsx_fp)) |> 
    clean_names() 
  
  
  vote_pres_2016 <- elec_2016|> 
    select(precinct_code,
           contains("g16pr")) # 'g16pr; is the code for presidential election results
  
  # Join
  
  vote_pres_2016 <- prec_2016 |> 
    select(county, 
           preccode, 
           precname,
           precinct_code = st_code) |> 
    left_join(vote_pres_2016, by = "precinct_code") |> 
    mutate(preccode = as.character(preccode))
  
  
  return(vote_pres_2016)
}

make_drove_alone_2012_2016 <- function(year = 2016){
  
  drove_alone_2012_2016 <- get_acs(
    geography = "tract",
    variables = c("B08006_001","B08006_003"), 
    state = "WA",
    year = year, 
    geometry = TRUE,
    output = "wide"
  ) |> 
    to_proj_crs() |> 
    clean_names() |> 
    tibble() |> 
    st_sf() |> 
    mutate(drove_alone_pct = b08006_003e/b08006_001e,
           drove_alone_pct_moe = moe_prop(
             num = b08006_003e,
             denom = b08006_001e,
             moe_num = b08006_003m,
             moe_denom = b08006_001m
           )) |> 
    mutate(flag_moe = case_when(
      b08006_001m >= b08006_001e ~ TRUE,
      b08006_003m >= b08006_003e ~ TRUE,
      drove_alone_pct_moe >= drove_alone_pct ~ TRUE,
      TRUE ~ FALSE
    ))
    
  
  return(drove_alone_2012_2016)
}

make_medianinc_2012_2016 <- function(year = 2016){
  medianinc_2012_2016 <- get_acs(
    geography = "tract",
    variables = "B19013_001", 
    state = "WA",
    year = year, 
    geometry = TRUE 
  ) |> 
    to_proj_crs() |> 
    clean_names() |> 
    tibble() |> 
    st_sf()
  
  return(medianinc_2012_2016)
}

# UTILITY FUNCTIONS -------------------------------------------------------

to_proj_crs <- function(sf){
  st_transform(sf, 6152)
}


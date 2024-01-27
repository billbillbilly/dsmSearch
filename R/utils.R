#' @import sf
#' @importFrom graphics par
#' @importFrom grDevices rgb
#' @importFrom utils download.file

#' @noMd
# create a buffer based on a given point
get_buffer <- function(x, y, r) {
  pdf <- data.frame(row.names = 1)
  pdf[1,"x"] <- x
  pdf[1,"y"] <- y
  p <- sp::SpatialPoints(pdf)
  p <- sf::st_as_sf(p)
  subarea <- sf::st_buffer(p, r)
  return(subarea)
}

#' @noMd
# create a request of the TNMAccess API
return_response <- function(bbox, max_return) {
  api1 <- 'https://tnmaccess.nationalmap.gov/api/v1/products?bbox='
  api2 <- paste0(bbox[1], ",",
                 bbox[2], ",",
                 bbox[3], ",",
                 bbox[4])
  api3 <- paste0('&datasets=Lidar%20Point%20Cloud%20(LPC)&max=',
                 max_return,
                 '&prodFormats=LAS,LAZ')
  json <- httr2::request(paste0(api1, api2, api3)) %>%
    httr2::req_timeout(10000) %>%
    httr2::req_perform() %>%
    httr2::resp_body_json()
  items <- length(json$items)
  cat(paste0("Get ", items, " returns", "\n"))
  cat(paste0("Find available items: ", json$total, "\n"))
  if (json$total > items) {
    cat("There are more available items\n")
    cat("You can set a greater return number to return\n")
  }
  titles <- c()
  sourceId <- c()
  metaUrl <- c()
  sizeInBytes <- c()
  startYear <- c()
  previewGraphicURL <- c()
  downloadLazURL <- c()
  if (items >= 1) {
    for (i in 1:items) {
      item <- json[[2]][[i]]
      titles <- c(titles, item$title)
      sourceId <- c(sourceId, item$sourceId)
      url <- paste0(item$metaUrl, "?format=json")
      metaUrl <- c(metaUrl, url)
      sizeInBytes <- c(sizeInBytes, item$sizeInBytes)
      startYear <- c(startYear, find_year(url))
      previewGraphicURL <- c(previewGraphicURL, item$previewGraphicURL)
      downloadLazURL <- c(downloadLazURL, item$downloadLazURL)
    }
    df <- data.frame(titles, sourceId,
                     metaUrl, sizeInBytes,
                     startYear, previewGraphicURL,
                     downloadLazURL)
    return(df)
  }
}

#' @noMd
# find year
find_year <- function(url) {
  j <- httr2::request(url) %>%
    httr2::req_timeout(10000) %>%
    httr2::req_perform() %>%
    httr2::resp_body_json()
  date <- j$dates[[2]]$dateString %>% strsplit("-") %>% unlist()
  return(as.integer(date[1]))
}

#' @noMd
paral_nix <- function(X, dsm, r, offset, workers){
  results <- pbmcapply::pbmclapply(X = X,
                                   FUN=radius_viewshed,
                                   dsm=dsm,
                                   r=r,
                                   offset=offset,
                                   mc.cores=workers)
  return(results)
}

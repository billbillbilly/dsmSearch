#' get_dsm_30
#' @description Search for and download ALOS Global Digital Surface Model (AW3D30)
#' via OpenTopography API 1.0.0 based on coordinates of a spatial point with
#' a given distance or bounding box. The raster resolution is 30 meter.
#'
#' @param x numeric, indicating Longtitude degree of the center point.
#' @param y numeric, indicating latitude degree of the center point.
#' @param r numeric, indicating search distance (meter or feet) for LiDAR data.
#' @param epsg numeric, the EPSG code specifying the coordinate reference system.
#' @param bbox vector, a bounding box defining the geographical area for downloading data.
#' @param key character, API key of OpenTopography.
#' @param folder character, indicating a path for downloading the data
#'
#' @return raster
#'
#' @details To request an API key of OpenTopography, online registeration is needed.
#'
#' @examples
#' \dontrun{
#' data <- dsmSearch::get_dsm_30(bbox = c(-83.783557,42.241833,-83.696525,42.310420),
#'                              folder = '/path/to/folder')
#' data <- dsmSearch::get_dsm_30(x = -83.741289, y = 42.270146, r = 1000, epsg = 2253,
#'                              folder = '/path/to/folder')
#' }
#'
#'
#' @importFrom terra rast
#' @importFrom httr2 resp_body_raw
#'
#' @export

get_dsm_30 <- function(x, y, r, epsg, bbox,
                       key= "demoapikeyot2022",
                       folder) {
  # create bbox
  if (missing(bbox)) {
    if (missing(epsg)) {
      stop("epsg is missing. Please set epsg code")
    }
    if (missing(x) || missing(y) || missing(r)) {
      stop("please specify x, y, and r, or bbox")
    } else {
      proj <- sp::CRS(paste0("+init=epsg:", epsg))
      longlat <- sp::CRS("+proj=longlat")
      bbox <- pt2bbox(x, y, r, proj, longlat)[[1]]
    }
  }
  # request data
  response <- return_response2(bbox, key)
  # download data
  if (!missing(folder)) {
    original_timeout <- getOption('timeout')
    options(timeout=9999)
    destination <- paste0(folder, "/", "output", ".tif")
    if (response$status_code == 200) {
      writeBin(httr2::resp_body_raw(response), destination)
      options(timeout=original_timeout)
      return(terra::rast(destination))
    }
  } else {
    message("folder is missng. Please set the path for downloading the DSM data")
  }

}



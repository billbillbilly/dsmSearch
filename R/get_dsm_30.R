#' get_dsm_30
#' @description Search for and download ALOS Global Digital Surface Model (AW3D30) and
#' USGS DEM raster datasets via OpenTopography API 1.0.0 based on coordinates of a spatial
#' point with a given distance or bounding box. The resolution of AW3D30 (ALOS World 3D 30m)
#' and SRTMGL1 (SRTM GL1 30m) raster is 30 meter.
#' The raster resolutions of USGS datasets are 10m and 1m.
#'
#' @param x numeric, indicating Longtitude degree of the center point.
#' @param y numeric, indicating latitude degree of the center point.
#' @param r numeric, indicating search distance (meter or feet) for LiDAR data.
#' @param epsg numeric, the EPSG code specifying the coordinate reference system.
#' @param bbox vector, a bounding box defining the geographical area for downloading data.
#' @param datatype character, dataset names including "AW3D30", "SRTMGL1", "USGS1m", "USGS10m".
#' @param key character, API key of OpenTopography.
#'
#' @return raster
#'
#' @details To request an API key of OpenTopography,
#' online registeration is needed: https://portal.opentopography.org/login?redirect=%2FrequestService%3Fservice%3Dapi.
#'
#' @examples
#' \dontrun{
#' data <- dsmSearch::get_dsm_30(bbox = c(-83.783557,42.241833,-83.696525,42.310420),
#'                               key = "API key")
#' data <- dsmSearch::get_dsm_30(x = -83.741289,
#'                               y = 42.270146,
#'                               r = 1000,
#'                               epsg = 2253,
#'                               key = "API key")
#' }
#'
#' @importFrom terra rast
#' @importFrom terra as.matrix
#' @importFrom terra ext
#' @importFrom terra crs
#' @importFrom httr2 resp_body_raw
#'
#' @export

get_dsm_30 <- function(x, y, r, epsg, bbox,
                       datatype='AW3D30',
                       key= "") {
  if (key == "") {
    stop("key is missing.")
  }
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
  response <- return_response2(bbox, key, datatype)
  # Store the original 'timeout' option and ensure it's reset upon function exit
  original_timeout <- getOption('timeout')
  on.exit(options(timeout = original_timeout), add = TRUE)
  options(timeout=9999)
  # download data
  if (response$status_code == 200) {
    temp_file <- tempfile(fileext = ".tif")
    writeBin(httr2::resp_body_raw(response), temp_file)
    out <- terra::rast(temp_file)
    out_m <- terra::as.matrix(out, wide=TRUE)
    out_ext <- terra::ext(out)
    out_crs <- terra::crs(out)
    new_rast <- terra::rast(out_m, extent = out_ext, crs = out_crs)
    unlink(temp_file)
    return(new_rast)
  }
}



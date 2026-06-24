# canopy_height_internal.R
#
# Internal implementations of canopy height download functions.
# Ported from the forestdata package (https://github.com/Cidree/forestdata,
# https://rdrr.io/cran/forestdata/src/R/canopy-height.R) under GPL-3.
# This avoids a runtime dependency on the forestdata package.

# ---- Helper: download a URL to a temp file and read as SpatRaster ----
.dsm_download_raster <- function(url, cache_file, timeout = 5000) {
  tryCatch({
    if (!file.exists(cache_file)) {
      old_timeout <- getOption("timeout")
      on.exit(options(timeout = old_timeout))
      options(timeout = max(timeout, getOption("timeout")))
      utils::download.file(url = url, destfile = cache_file,
                           quiet = TRUE, mode = "wb")
    }
    if (!file.exists(cache_file)) return(NULL)
    terra::rast(cache_file)
  }, error = function(e) NULL)
}

# ---- ETH Global Sentinel-2 10 m Canopy Height (2020) ----
#
# Tiles follow a 3-degree grid.
# URL format (Lang et al. 2022):
#   https://libdrive.ethz.ch/index.php/s/cO8or7iOe5dT2Zm/download?path=/&files=
#   ETH_GlobalCanopyHeight_10m_2020_{NS}{lat02d}{EW}{lon03d}_Map[_SD].tif
.fd_canopy_height_eth <- function(x, layer = "chm", crop = FALSE, merge = TRUE) {
  xwgs84 <- sf::st_transform(x, crs = "EPSG:4326")
  xbbox  <- sf::st_bbox(xwgs84)

  # 3-degree tile grid
  lon_seq <- seq(floor(xbbox["xmin"] / 3) * 3, floor(xbbox["xmax"] / 3) * 3, 3)
  lat_seq <- seq(floor(xbbox["ymin"] / 3) * 3, floor(xbbox["ymax"] / 3) * 3, 3)

  eth_base     <- "https://libdrive.ethz.ch/index.php/s/cO8or7iOe5dT2Zm/download?path=/&files="
  layer_suffix <- if (layer == "std") "_SD" else ""

  tiles_list <- list()
  for (lat_i in lat_seq) {
    for (lon_i in lon_seq) {
      lat_ns <- if (lat_i >= 0) "N" else "S"
      lon_ew <- if (lon_i >= 0) "E" else "W"
      fname  <- sprintf("ETH_GlobalCanopyHeight_10m_2020_%s%02d%s%03d_Map%s.tif",
                        lat_ns, abs(lat_i), lon_ew, abs(lon_i), layer_suffix)
      url        <- paste0(eth_base, fname)
      cache_file <- file.path(tempdir(), fname)
      r <- .dsm_download_raster(url, cache_file)
      if (!is.null(r)) tiles_list <- c(tiles_list, list(r))
    }
  }

  if (length(tiles_list) == 0)
    stop("`get_dsm_30()` could not download any ETH canopy height tiles for this area. ",
         "The service may be temporarily unavailable, or no data exist here.")

  # Suppress terra progress bars temporarily
  user_opts <- terra::terraOptions(print = FALSE)
  terra::terraOptions(progress = 0)
  on.exit(terra::terraOptions(progressbar = user_opts$progress), add = TRUE)

  if (crop)
    tiles_list <- lapply(tiles_list, function(r) terra::crop(r, xwgs84))

  if (merge && length(tiles_list) > 1) {
    ch_sr <- tiles_list[[1]]
    for (i in seq(2, length(tiles_list)))
      ch_sr <- terra::merge(ch_sr, tiles_list[[i]])
  } else if (!merge && length(tiles_list) > 1) {
    ch_sr <- terra::sprc(tiles_list)
  } else {
    ch_sr <- tiles_list[[1]]
  }

  names(ch_sr) <- layer
  ch_sr
}

# ---- Meta High Resolution 1 m Global Canopy Height Map ----
#
# Tiles are identified by QuadKey strings stored in a GeoJSON index on S3.
# aws.s3 (CRAN) is required at runtime to download individual tiles.
.fd_canopy_height_meta <- function(x, crop = FALSE, merge = TRUE) {
  if (!requireNamespace("aws.s3", quietly = TRUE))
    stop("Package 'aws.s3' is required to download Meta CHM tiles. ",
         "Install it with: install.packages('aws.s3')")

  xwgs84 <- sf::st_transform(x, crs = "EPSG:4326")

  # Download the tile spatial index once per R session
  tiles_cache <- file.path(tempdir(), "meta_chm_tiles.geojson")
  if (!file.exists(tiles_cache)) {
    tryCatch(
      utils::download.file(
        url      = paste0("https://dataforgood-fb-data.s3.amazonaws.com/",
                          "forests/v1/alsgedi_global_v6_float/tiles.geojson"),
        destfile = tiles_cache,
        quiet    = TRUE,
        mode     = "wb"
      ),
      error = function(e)
        stop("Failed to download Meta CHM tile index: ", conditionMessage(e))
    )
  }

  meta_tiles <- sf::read_sf(tiles_cache)
  # The tile identifier column is named "tile" in the forestdata package;
  # fall back to the first non-geometry column if it differs.
  tile_col <- if ("tile" %in% names(meta_tiles)) "tile" else names(meta_tiles)[1]
  tile_vec <- meta_tiles |>
    sf::st_filter(xwgs84) |>
    dplyr::pull(!!tile_col)

  if (length(tile_vec) == 0)
    stop("No Meta CHM tiles found for this area.")

  out_files <- file.path(tempdir(), paste0(tile_vec, ".tif"))
  for (i in seq_along(tile_vec)) {
    if (!file.exists(out_files[i])) {
      try(
        aws.s3::save_object(
          object = paste0("forests/v1/alsgedi_global_v6_float/chm/",
                          tile_vec[i], ".tif"),
          bucket = "dataforgood-fb-data",
          file   = out_files[i],
          region = "us-east-1"
        ),
        silent = TRUE
      )
    }
    if (!file.exists(out_files[i]))
      stop("Failed to download Meta CHM tile: ", tile_vec[i])
  }

  r <- lapply(out_files, terra::rast)

  if (crop) {
    x_3857 <- sf::st_transform(xwgs84, crs = "EPSG:3857")
    r <- lapply(r, function(ri) terra::crop(ri, x_3857))
  }

  if (merge && length(r) > 1) {
    r_final <- r[[1]]
    for (i in seq(2, length(r))) r_final <- terra::merge(r_final, r[[i]])
  } else if (!merge && length(r) > 1) {
    r_final <- terra::sprc(r)
  } else {
    r_final <- r[[1]]
  }

  names(r_final) <- "canopy_height"
  r_final
}

# ---- Dispatcher (mirrors forestdata::fd_canopy_height) ----
.fd_canopy_height <- function(x = NULL, model = "eth", layer = "chm",
                               crop = FALSE, merge = FALSE) {
  if (is.null(x))
    stop("x must be an sf or SpatVector object.")
  if (inherits(x, "SpatVector"))
    x <- sf::st_as_sf(x)
  if (!model %in% c("eth", "meta"))
    stop("model must be \"eth\" or \"meta\".")

  if (model == "eth") {
    .fd_canopy_height_eth(x = x, layer = layer, crop = crop, merge = merge)
  } else {
    .fd_canopy_height_meta(x = x, crop = crop, merge = merge)
  }
}

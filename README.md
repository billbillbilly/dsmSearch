
<!-- badges: start -->

[![R-CMD-check](https://github.com/land-info-lab/dsmSearch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/land-info-lab/dsmSearch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

# dsmSearch

<p align="left">

<img src="dsmsearch_hex-02.png" height="200">

</p>

## Introduction

The dsmSearch R pacakge can currently be installed via github.

``` r
library(devtools)
install_github("land-info-lab/dsmSearch", dependencies=TRUE)
```

Baesd on the TNMAccess API, LiDAR search facilitate the retrieval and
exploration of LiDAR (Light Detection and Ranging) data (from USGS)
within a specified bounding box (bbox). This function enables users to
search for LiDAR data, preview available graphics, and optionally
download LiDAR data files for further viewscape analysis. Current
dataset of USGS covers the most area in the US:
<https://apps.nationalmap.gov/lidar-explorer/#/>

``` r
# search for lidar data information using bbox
search_result <- dsmSearch::lidar_search(bbox = c(-83.742282,42.273389,-83.733442,42.278724), preview = TRUE)
#> Get 5 returns
#> Find available items: 5
```

<img src="man/figures/README-unnamed-chunk-2-1.png" width="100%" />

From viewshed analysis, the visible area of a viewpoint is presented by
visible points. There are several viewshed metrics such as can be
calculated based on the visible points. For further information on these
metrics and the rest of the functions available in this package please
refer to the [package
website](https://billbillbilly.github.io/viewscape/). For more
information and examples of the functions check out the [package
vignette](needs%20to%20be%20created).

## Issues and bugs

This package may take a long time to run if using spatially large or
high resolution digital elevation models.

If you discover a bug not associated with connection to the API that is
not already a [reported
issue](https://github.com/billbillbilly/viewscape/issues), please [open
a new issue](https://github.com/billbillbilly/viewscape/issues/new)
providing a reproducible example.

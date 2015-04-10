pkgs <- c("party", "ggplot2", "reshape2", "stringr", "xtable", "countrycode",
          "doParallel", "dplyr", "tidyr", "devtools")

install.packages(pkgs)

library(devtools)
install_github("zmjones/edarf")

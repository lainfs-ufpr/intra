# se você utiliza linux/ubuntu pode ser que faltem algumas libs de próprio sistema operacional com relação a instalação do shortread, 
# para mais informações leia o README do projeto

source("scripts/instalar_pacotes.R")
cran_pkgs <- c("shiny", "ggplot2", "fs", "scales", "plotly", "viridis", 
               "shinyjs", "shinyWidgets", "shinyFiles", "bslib", "dplyr",
               "tidyverse", "peakRAM") 
bioc_pkgs <- c("ShortRead")
instalar_pacotes(cran_pkgs, install.packages)
instalar_pacotes(bioc_pkgs, BiocManager::install)

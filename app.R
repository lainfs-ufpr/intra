library(shiny)
library(ShortRead)
library(ggplot2)
library(fs)
library(scales)
library(plotly)
library(viridis)
library(shinyjs)
library(shinyWidgets)

# Tamanho máximo de input
options(shiny.maxRequestSize = 100 * 1024^3)

source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
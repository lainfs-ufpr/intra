library(bslib)
library(shinyjs)
library(shinyFiles)
library(shinyWidgets)

# Carregando UI
source("ui_qualidade.R")
source("ui_trimagem.R")

# FRONT

ui <- fluidPage(
  
  theme = bs_theme(version = 5,
                   bootswatch = "flatly", 
                   base_font = font_google("Lexend Deca")),

  useShinyjs(),
  
  # CSS
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "apresent.css")),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "qualidade.css")),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "trimagem.css")),
  
  # Página de Navegação
  page_navbar(
    # HEADER
    title = tags$span(tags$img(src = "logo-principal-sf.png", id = "logo-fixo"),
                      "INTRA",
                      class = "titulo-app",
                      style = "margin-right: 60px;"
    ),
    
    # QUALIDADE 
    nav_panel("Qualidade",
              qualidadeUI("qualidade_id") 
    ), 
    
    # TRIMAGEM
    nav_panel("Trimagem",
              trimagemUI("trimagem_id")
    ), 
    
    nav_spacer(),
    
    # Controlador de modo claro/escuro
    nav_item(input_dark_mode(id = "mode", mode = "light")), 
    
    id = "page"
  )
)
library(shinyjs)
library(shinyWidgets)

qualidadeUI <- function(id) {
  ns <- NS(id)
  
  sidebarLayout(
    # Sidebar
    sidebarPanel(width = 3,
                 class = "sidebar",
                 tags$h4("Para inicializar a análise, selecione o(s) arquivo(s) ou uma pasta", 
                         class = "titulo-sidebar"),
                 
                 div(class = "painel-arquivos",
                     div(class = "linha-arquivos",
                         shinyDirButton(class = "botao-diretorio",
                                        ns("diretorio"), "Adicionar uma pasta", "Selecionar"), 
                         div(class = "coluna-arquivo",
                             tags$span("Adicionar um arquivo", class = "message-input"),
                             div(class = "botao-arquivo",
                                 fileInput(ns("arquivos"), label = NULL, multiple = TRUE,
                                           accept = c(".fasta", ".fa", ".fastq", ".fq", "text/plain"))
                             )
                         )
                     ),
                    div(id = ns("loading_animation"), class = "loading_animation"),
                    actionButton(ns("run_analysis"), "Rodar controle de qualidade", class = "btnQA-custom")
                 ),
                 
                 tags$br(),
                 
                 div(class = "botao-cor",
                     selectInput(ns("palette_choice"), "Mude a paleta de cores aqui:",
                                 choices = c("viridis", "magma", "plasma", "rocket",
                                             "cividis", "inferno", "turbo", "mako"),
                                 selected = "viridis")
                     )
    ),
    
    # Paineis de gráficos
    mainPanel(width = 9,
              navset_pill(
                nav_panel("Qualidade por Ciclo",
                          plotOutput(ns("plot_qualidade_ciclo_est")),
                          ui_download_plot(ns, "ciclo") 
                ),
                nav_panel("Qualidade Média",
                          plotOutput(ns("plot_qualidade_media_est")),
                          ui_download_plot(ns, "media")
                ),
                nav_panel("Contagem de Bases",
                          plotOutput(ns("plot_contagens_est")),
                          ui_download_plot(ns, "contagens")
                ),
                nav_panel("Distribuição Cumulativa de Leituras",
                          plotOutput(ns("plot_ocorrencias_est")),
                          ui_download_plot(ns, "ocorrencias")
                ),
                nav_panel("Sequências Frequentes",
                          tableOutput(ns("tabela_frequencias"))
                ),
                nav_panel("Contaminação por Adaptadores",
                          #plotOutput(ns("plot_adapters_est")),
                          #ui_download_plot(ns, "adapters"),
                          tableOutput(ns("tabela_adapters"))
                )
              ),
              br(),
              hr(),
              
              div(
                id = ns("qa_output"),
                style = "margin-top:10px"
              ),
              
              div(style = "margin-left: 20px;", textOutput(ns("caminhoPasta")))
    )
  )
}

ui_download_plot <- function(ns, plot_name) {
  shinyjs::hidden(
    div(id = ns(paste0("wrapper_download_", plot_name)), class = "btn-download-plot",
        dropdownButton(
          inputId = ns(paste0("download_opts_", plot_name)),
          label = "Baixar gráfico", 
          icon = icon("download"),
          status = "primary",
          circle = FALSE,
          inline = TRUE,
          
          selectInput(ns(paste0("formato_download_", plot_name)), "Formato:",
                      choices = c("png", "pdf", "jpeg", "svg"),
                      selected = "pdf"),
          downloadButton(ns(paste0("download_plot_", plot_name)), "Download")
        )
    )
  )
}
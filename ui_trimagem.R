trimagemUI <- function(id) {
  ns <- NS(id) 
  
  sidebarLayout(
    sidebarPanel(
      class = "sidebar-trim",
      
      radioButtons(ns("mode"), "Tipo de leitura:",
                   choices = c("Single-end" = "SE", "Paired-end" = "PE"),
                   selected = "SE"),
      
      conditionalPanel(
        condition = "input.mode == 'SE'",
        ns = ns,
        div(class = "botao-arquivo",
            fileInput(ns("r1"), 
                      "FASTQ R1 (gzip aceito .fastq(.gz))", 
                      accept = c(".fastq", ".fq", ".fastq.gz", ".fq.gz")
            )
        )
      ),
      
      conditionalPanel(
        condition = "input.mode == 'PE'",
        ns = ns,
        div(class = "lado-lado",
            div(class = "botao-arquivo",
                fileInput(ns("r1"), 
                          "FASTQ R1 (gzip aceito .fastq(.gz))", 
                          accept = c(".fastq", ".fq", ".fastq.gz", ".fq.gz")
                )
            ),
            div(class = "botao-arquivo",
                fileInput(ns("r2"), 
                          "FASTQ R2 (gzip aceito .fastq(.gz))", 
                          accept = c(".fastq", ".fq", ".fastq.gz", ".fq.gz")
                ) 
            )
        )
      ),
      
      div(class = "botao-arquivo",
          fileInput(
            ns("trimmomatic_jar"),
            "Arquivo Trimmomatic (.jar)",
            accept = ".jar"
          )),
      
      # Adaptadores filtrados por modo SE
      conditionalPanel(
        condition = "input.mode == 'SE'",
        ns = ns,
        selectInput(ns("adapter_choice"), "Escolher adaptador:",
                    choices = c("TruSeq3-SE" = "TruSeq3-SE.fa",
                                "TruSeq2-SE" = "TruSeq2-SE.fa",
                                "Custom (inserir manualmente)" = "custom"),
                    selected = "TruSeq3-SE.fa")
      ),
      
      # Adaptadores filtrados por modo PE
      conditionalPanel(
        condition = "input.mode == 'PE'",
        ns = ns,
        selectInput(ns("adapter_choice"), "Escolher adaptador:",
                    choices = c("TruSeq3-PE" = "TruSeq3-PE.fa",
                                "TruSeq2-PE" = "TruSeq2-PE.fa",
                                "NexteraPE"  = "NexteraPE-PE.fa",
                                "Custom (inserir manualmente)" = "custom"),
                    selected = "TruSeq3-PE.fa")
      ),
      
      conditionalPanel(
        condition = "input.adapter_choice == 'custom'", 
        ns = ns, 
        textInput(ns("custom_adapter"), "Caminho completo do arquivo de adaptadores:",
                  value = "")
      ),
      
      div(class = "coluna",
          div(class = "lado-lado",
              numericInput(
                ns("window_size"),
                label = tagList(
                  bslib::tooltip(
                    trigger = icon("info-circle"),
                    "Número de bases analisadas por vez",
                    placement = "bottom",
                    class = "info-icon"
                  ),
                  "SLIDINGWINDOW"
                ),
                value = 4, min = 1
              ),
              
              numericInput(
                ns("qual_cut"),
                label = tagList(
                  bslib::tooltip(
                    trigger = icon("info-circle"),
                    "Qualidade média mínima dentro da janela de bases analisadas, utilizado para remover regiões de queda gradual de qualidade",
                    placement = "bottom",
                    class = "info-icon"
                  ),
                  "CUTOFF"
                ),
                value = 20, min = 2
              )
          ),
          
          numericInput(
            ns("minlen"),
            label = tagList(
              bslib::tooltip(
                trigger = icon("info-circle"),
                "Comprimento minímo, reads com menos bp do que o indicado serão removidos",
                placement = "bottom",
                class = "info-icon"
              ),
              "MINLEN"
            ),
            value = 25, min = 1
          ),
          
          div(class = "lado-lado",
              numericInput(
                ns("leading"),
                label = tagList(
                  bslib::tooltip(
                    trigger = icon("info-circle"),
                    "Remove as bases com qualidade menor que o indicado no início da sequência, 
                    para no momento que encontra uma base com qualidade superior ao indicado",
                    placement = "bottom",
                    class = "info-icon"
                  ),
                  "LEADING"
                ),
                value = 3, min = 0
              ),
              
              numericInput(
                ns("trailing"),
                label = tagList(
                  bslib::tooltip(
                    trigger = icon("info-circle"),
                    "Remove as bases com qualidade menor que o indicado no final da sequência,
                    para no momento que encontra uma base com qualidade superior ao indicado",
                    placement = "bottom",
                    class = "info-icon"
                  ),
                  "TRAILING"
                ),
                value = 3, min = 0
              )
          )
      ),
      
      # Botão com spinner de carregamento
      div(
        style = "position: relative;",
        actionButton(
          ns("run"),
          label = tagList(
            tags$span(
              id = ns("run_spinner"),
              class = "spinner-border spinner-border-sm me-2",
              role = "status",
              style = "display:none; vertical-align:middle;"
            ),
            "Rodar Trimmomatic"
          ),
          class = "btnQA-custom"
        ),
        tags$script(HTML(paste0("
          $(document).on('shiny:inputchanged', function(e) {
            if (e.name === '", ns("run"), "') {
              $('#", ns("run_spinner"), "').show();
              $('#", ns("run"), "').prop('disabled', true);
            }
          });
          $(document).on('shiny:value shiny:error', function(e) {
            if (e.name === '", ns("stats_table"), "') {
              $('#", ns("run_spinner"), "').hide();
              $('#", ns("run"), "').prop('disabled', false);
            }
          });
        ")))
      ),
      
      div(
        id = ns("trim_output"),
        style = "margin-top:10px"
      ),
      
      hr(),
      
      uiOutput(ns("download_log_ui")),
      
      conditionalPanel(
        condition = "input.mode == 'PE'",
        ns = ns,
        downloadButton(ns("download_r1_paired"), 
                       "Download R1_paired",
                       class = "btn-trim-download"),
        downloadButton(ns("download_r2_paired"), 
                       "Download R2_paired",
                       class = "btn-trim-download") 
      ),
      
      conditionalPanel(
        condition = "input.mode == 'SE'",
        ns = ns,
        downloadButton(ns("download_single_trimmed"), 
                       "Download SE_trimmed", 
                       class = "btn-trim-download")
      )
    ),
    
    mainPanel(
      div(class = "trim-main-panel",
          h4("Estatísticas (antes x depois)"),
          tableOutput(ns("stats_table")), 
          h4("Plot: qualidade média por ciclo (R1)"),
          uiOutput(ns("qual_plot_ui"))
      )
    )
  )
}
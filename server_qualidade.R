library(shinyjs)
library(shinyWidgets)

# Tamanho máximo de input
options(shiny.maxRequestSize = 100 * 1024^3)

qualidadeServer <- function(id, r_dir_path, r_resultado_qa) {

  moduleServer(id, function(input, output, session) {
    
    paleta_cores <- reactive({
      req(input$palette_choice)
      tolower(input$palette_choice)
    })
    
    nomes_arquivos <- reactive({
      # Prioriza arquivos carregados
      if (!is.null(input$arquivos)) {
        return(input$arquivos$name)
      }
      
      # Se uma pasta foi selecionada e o caminho não é nulo/vazio
      fls <- get_files_for_analysis()
      if (!is.null(r_dir_path()) && length(fls) > 0) {
        # Retorna o nome base dos caminhos encontrados na pasta
        return(basename(fls))
      }
      
      # Caso contrário, retorna NULL
      return(NULL)
    })
    
    # Helper para determinar a lista de arquivos (usado em Contagem de Bases e Adapters)
    get_files_for_analysis <- reactive({
      if (!is.null(input$arquivos)) {
        return(input$arquivos$datapath)
      } else if (!is.null(r_dir_path())) {
        pattern_regex <- "\\.(fq|fastq|fa|fasta)(\\.gz)?$"
        return(dir(r_dir_path(), pattern = pattern_regex, full.names = TRUE))
      } else {
        return(NULL)
      }
    })
    
    volumes <- c(Home = fs::path_home(), "C:" = "C:/", "D:" = "D:/")
    # Usa input$diretorio do namespace do módulo
    shinyDirChoose(input, "diretorio", roots = volumes, session = session)
    
    observeEvent(input$diretorio, {
      path <- parseDirPath(volumes, input$diretorio)
      r_dir_path(path) # Atualiza o reativo global
    })
    
    output$caminhoPasta <- renderText({
      req(r_dir_path())
      paste("Pasta selecionada:", r_dir_path())
    })
    
    observeEvent(input$run_analysis, {
      
      shinyjs::hide("run_analysis")
      shinyjs::show("loading_animation")
      shinyjs::html(session$ns("qa_output"), '<b style="color: black;">Controle de Qualidade em andamento...</b>')
      
      shinyjs::delay(100, {
        fls <- get_files_for_analysis()
      
        if (is.null(fls) || length(fls) == 0) {
          showNotification("Nenhum arquivo FASTQ encontrado!", type = "error")
          shinyjs::show(session$ns("run_analysis"))
          shinyjs::hide(session$ns("loading_animation"))
          return()
        }
      
        tryCatch({
          tempo_inicio <- Sys.time()
        
          resultado <- qa(fls, type = "fastq")
          r_resultado_qa(resultado) 
        
          shinyjs::show("wrapper_download_ciclo")
          shinyjs::show("wrapper_download_media")
          shinyjs::show("wrapper_download_contagens")
          shinyjs::show("wrapper_download_ocorrencias")
          shinyjs::show("wrapper_download_adapters")
        
          tempo_execucao <- Sys.time() - tempo_inicio
          shinyjs::html(session$ns("qa_output"),
                        paste0('<b style="color: #31231a">Controle de Qualidade finalizado! Tempo de execução:</b> ',
                              round(tempo_execucao, 2), 
                              ' segundos'))
        
          shinyjs::hide("loading_animation")
          shinyjs::show("run_analysis")
        
        }, error = function(e) {
          shinyjs::html(session$ns("qa_output"),
                        paste0('<b style="color: #940e01">Erro: ', e$message, '</b>'))
        
          shinyjs::hide("loading_animation")
          shinyjs::show("run_analysis")
        })
      })
    })
    
    # Plot qualidade ciclo
    output$plot_qualidade_ciclo_est <- renderPlot({
      req(r_resultado_qa())
      plotCycleQuality(r_resultado_qa(), paleta_cores(), nomes_arquivos())$p_estatico
    })
    
    # Download do plot qualidade ciclo
    output$download_plot_ciclo <- downloadHandler(
      filename = function() {
        paste0("qualidade_ciclo.", input$formato_download_ciclo)
      },
      content = function(file) {
        req(r_resultado_qa(), paleta_cores(), input$formato_download_ciclo)
        
        p <- plotCycleQuality(r_resultado_qa(), paleta_cores(), nomes_arquivos())$p_estatico
        
        ggsave(filename = file, plot = p, width = 8, height = 6, device = input$formato_download_ciclo)
      }
    )
    
    # Plot qualidade média 
    output$plot_qualidade_media_est <- renderPlot({
      req(r_resultado_qa())
      readQualityScore(r_resultado_qa(), paleta_cores(), nomes_arquivos())$p_estatico
    })
    
    # Download do plot qualidade média 
    output$download_plot_media <- downloadHandler(
      filename = function() {
        paste0("media.", input$formato_download_media)
      },
      content = function(file) {
        req(r_resultado_qa(), paleta_cores(), input$formato_download_media)
        
        p <- readQualityScore(r_resultado_qa(), paleta_cores(), nomes_arquivos())$p_estatico
        
        ggsave(filename = file, plot = p, width = 8, height = 6, device = input$formato_download_media)
      }
    )
    
    # Plot contagem bases
    output$plot_contagens_est <- renderPlot({
      fls <- get_files_for_analysis()
      req(fls)
      plotNucleotideCount(fls, paleta_cores(), nomes_arquivos())$p_estatico
    })
    
    # Download do plot contagem bases
    output$download_plot_contagens <- downloadHandler(
      filename = function() {
        paste0("contagens.", input$formato_download_contagens)
      },
      content = function(file) {
        fls <- get_files_for_analysis()
        req(fls, paleta_cores(), input$formato_download_contagens)
        
        p <- plotNucleotideCount(fls, paleta_cores(), nomes_arquivos())$p_estatico
        
        ggsave(filename = file, plot = p, width = 8, height = 6, device = input$formato_download_contagens)
      }
    )
    
    # Plot ocorrências
    output$plot_ocorrencias_est <- renderPlot({
      req(r_resultado_qa())
      plotOcurrences(r_resultado_qa(), paleta_cores(), nomes_arquivos())$p_estatico
    })
    
    # Download do plot ocorrências
    output$download_plot_ocorrencias <- downloadHandler(
      filename = function() {
        paste0("ocorrencias.", input$formato_download_ocorrencias)
      },
      content = function(file) {
        req(r_resultado_qa(), paleta_cores(), input$formato_download_ocorrencias)
        
        p <- plotOcurrences(r_resultado_qa(), paleta_cores(), nomes_arquivos())$p_estatico
        
        ggsave(filename = file, plot = p, width = 8, height = 6, device = input$formato_download_ocorrencias)
      }
    )
    
    # Tabela sequências frequentes
    output$tabela_frequencias <- renderTable({
      req(r_resultado_qa())
      t <- freqSequences(r_resultado_qa())
      
      nomes <- nomes_arquivos() 
      if (!is.null(nomes)) {
        # Mapeia e remove duplicados para exibição
        t$Arquivo <- nomes[match(t$Arquivo, unique(t$Arquivo))]
        t$Arquivo <- ifelse(duplicated(t$Arquivo),"",t$Arquivo)
      }
      t
    })
    
    # Tabela adapters
    output$tabela_adapters <- renderTable({
      fls <- get_files_for_analysis()
      req(fls)
      t <- tableAdapterContamination(fls)
      
      nomes <- nomes_arquivos() 
      if (!is.null(nomes)) {
        t$Arquivo <- nomes[match(t$Arquivo, unique(t$Arquivo))]
      }
      t
    })
    
  })
}
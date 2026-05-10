library(ShortRead)
library(ggplot2)
library(dplyr)

trimagemServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    trimmed_paths <- reactiveVal(NULL)
    log_path      <- reactiveVal(NULL)
    
    append_log <- function(path, msg) {
      cat(msg, "\n", file = path, append = TRUE)
    }
    
    observeEvent(input$run, {
      req(input$r1)
      mode <- input$mode
      
      r1_path <- input$r1$datapath
      r2_path <- if (!is.null(input$r2)) input$r2$datapath else NULL
      
      outdir <- file.path(tempdir(), paste0("trim_", format(Sys.time(), "%Y%m%d_%H%M%S")))
      dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
      
      log_file <- file.path(outdir, paste0("trimmomatic_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt"))
      log_path(log_file)
      cat("", file = log_file) # cria o arquivo vazio
      
      trimmomatic_jar <- input$trimmomatic_jar$datapath
      
      if (is.null(trimmomatic_jar) || !file.exists(trimmomatic_jar)) {
        append_log(log_file, "Arquivo JAR do Trimmomatic não encontrado.")
        return()
      }
      
      if (input$adapter_choice == "custom" && nzchar(input$custom_adapter)) {
        adapters_file <- input$custom_adapter
      } else {
        adapters_file <- file.path("data/adapters/", input$adapter_choice)
      }
      
      # parâmetros de trimming
      sw <- paste0("SLIDINGWINDOW:", input$window_size, ":", input$qual_cut)
      minlen <- paste0("MINLEN:", input$minlen)
      leading  <- paste0("LEADING:", input$leading)
      trailing <- paste0("TRAILING:", input$trailing)
      illum_clip <- paste0("ILLUMINACLIP:", adapters_file, ":2:30:10")
      
      # --- SINGLE-END ---
      if (mode == "SE") {
        out_se <- file.path(outdir, "trimmed_SE.fastq.gz")
        
        args <- c("-jar", shQuote(trimmomatic_jar),
                  "SE", "-phred33",
                  shQuote(r1_path), shQuote(out_se),
                  illum_clip, leading, trailing, sw, minlen)
        
        append_log(log_file, "Executando Trimmomatic (Single-end)...")
        flush.console()
        res <- tryCatch({
          out <- system2("java", args = args, stdout = TRUE, stderr = TRUE)
          append_log(log_file, paste(out, collapse = "\n"))
          TRUE
        }, error = function(e) {
          append_log(log_file, paste("Erro ao executar Trimmomatic:", e$message))
          FALSE
        })
        
        if (!res) {
          trimmed_paths(NULL)
          return()
        }
        
        trimmed_paths(list(single_trimmed = out_se, outdir = outdir))
        
        # Cálculo de stats
        stats <- tryCatch({
          raw_r1 <- readFastq(r1_path)
          trim_r1 <- readFastq(out_se)
          tibble::tibble(
            tipo = c("Raw", "Trimmed"),
            n_reads = c(length(raw_r1), length(trim_r1)),
            mean_length = c(mean(width(sread(raw_r1))), mean(width(sread(trim_r1))))
          )
        }, error = function(e) NULL)
        
      } else {
        # --- PAIRED-END ---
        req(r2_path)
        r1_paired  <- file.path(outdir, "R1_paired.fastq.gz")
        r1_unpaired <- file.path(outdir, "R1_unpaired.fastq.gz")
        r2_paired  <- file.path(outdir, "R2_paired.fastq.gz")
        r2_unpaired <- file.path(outdir, "R2_unpaired.fastq.gz")
        
        args <- c("-jar", shQuote(trimmomatic_jar),
                  "PE", "-phred33",
                  shQuote(r1_path), shQuote(r2_path),
                  shQuote(r1_paired), shQuote(r1_unpaired),
                  shQuote(r2_paired), shQuote(r2_unpaired),
                  illum_clip, leading, trailing, sw, minlen)
        
        append_log(log_file, "Executando Trimmomatic (Paired-end)...")
        flush.console()
        res <- tryCatch({
          out <- system2("java", args = args, stdout = TRUE, stderr = TRUE)
          append_log(log_file, paste(out, collapse = "\n"))
          TRUE
        }, error = function(e) {
          append_log(log_file, paste("Erro ao executar Trimmomatic:", e$message))
          FALSE
        })
        
        if (!res) {
          trimmed_paths(NULL)
          return()
        }
        
        trimmed_paths(list(r1_paired = r1_paired, r2_paired = r2_paired,
                           r1_unpaired = r1_unpaired, r2_unpaired = r2_unpaired,
                           outdir = outdir))
        
        # Cálculo de stats
        stats <- tryCatch({
          raw_r1 <- readFastq(r1_path)
          raw_r2 <- readFastq(r2_path)
          trim_r1 <- readFastq(r1_paired)
          trim_r2 <- readFastq(r2_paired)
          tibble::tibble(
            lado = c("R1_raw", "R2_raw", "R1_trimmed", "R2_trimmed"),
            n_reads = c(length(raw_r1), length(raw_r2), length(trim_r1), length(trim_r2)),
            mean_length = c(mean(width(sread(raw_r1))), mean(width(sread(raw_r2))),
                            mean(width(sread(trim_r1))), mean(width(sread(trim_r2))))
          )
        }, error = function(e) NULL)
      }
      
      # Estatísticas e plot
      output$stats_table <- renderTable({ stats }, digits = 0)
      
      output$qual_plot_ui <- renderUI({
        req(stats)
        fq_raw  <- readFastq(r1_path)
        fq_trim <- if (mode == "SE") readFastq(trimmed_paths()$single_trimmed) else readFastq(trimmed_paths()$r1_paired)
        
        if (length(fq_trim) == 0) {
          div(
            style = paste(
              "background:#fff3cd; color:#856404; border:1px solid #ffc107;",
              "border-radius:6px; padding:14px 18px; margin-top:8px;"
            ),
            icon("triangle-exclamation"),
            strong(" Nenhuma read sobreviveu à trimagem."),
            p("Todos os reads foram removidos com os parâmetros atuais. 
              Tente reduzir os valores de LEADING, TRAILING, CUTOFF ou MINLEN.",
              style = "margin:6px 0 0 0;")
          )
        } else {
          mean_quality_by_cycle <- function(fq) {
            Q <- as(quality(fq), "matrix")
            data.frame(pos = seq_len(ncol(Q)), meanQ = colMeans(Q, na.rm = TRUE))
          }
          
          mq_raw  <- mean_quality_by_cycle(fq_raw)
          mq_trim <- mean_quality_by_cycle(fq_trim)
          
          output$qual_plot_render <- renderPlot({
            ggplot() +
              geom_line(data = mq_raw,  aes(x = pos, y = meanQ), color = "blue", linetype = "dashed") +
              geom_line(data = mq_trim, aes(x = pos, y = meanQ), color = "red") +
              theme_minimal() +
              labs(x = "Ciclo", y = "Qualidade média",
                   title = paste("Qualidade média (", mode, ")")) +
              scale_x_continuous(expand = c(0, 0))
          })
          
          plotOutput(session$ns("qual_plot_render"), height = "360px")
        }
      })
      
      append_log(log_file, paste("\nTrimagem finalizada. Arquivos em:", outdir))
    })
    
    output$download_log_ui <- renderUI({
      req(log_path())
      downloadButton(session$ns("download_log"), "Download log (.txt)", class = "btn-trim-download")
    })
    
    output$download_log <- downloadHandler(
      filename = function() basename(log_path()),
      content  = function(file) file.copy(log_path(), file)
    )
    
    output$download_r1_paired <- downloadHandler(
      filename = function() basename(trimmed_paths()$r1_paired),
      content = function(file) file.copy(trimmed_paths()$r1_paired, file)
    )
    output$download_r2_paired <- downloadHandler(
      filename = function() basename(trimmed_paths()$r2_paired),
      content = function(file) file.copy(trimmed_paths()$r2_paired, file)
    )
    output$download_single_trimmed <- downloadHandler(
      filename = function() basename(trimmed_paths()$single_trimmed),
      content = function(file) file.copy(trimmed_paths()$single_trimmed, file)
    )
  })
}
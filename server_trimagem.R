library(ShortRead)
library(ggplot2)
library(dplyr)

options(shiny.maxRequestSize = 100 * 1024^3)

trimagemServer <- function(id) {
  
  moduleServer(id, function(input, output, session) {
    
    trimmed_paths <- reactiveVal(NULL)
    log_path <- reactiveVal(NULL)
    
    append_log <- function(path,msg){
      cat(msg,"\n",file=path,append=TRUE)
    }
    
   read_sample_fastq <- function(file,n=100000){
      stream <- FastqStreamer(file,n=n)
      fq <- yield(stream)
      close(stream)
      fq
    }
    
 # Calcula estatísticas
    calc_stats <- function(raw,trim){
       tibble(
        n_reads=c(length(raw),length(trim)),
        mean_length=c(
          mean(width(sread(raw))),
          mean(width(sread(trim)))
        )
      )
   }
     observeEvent(input$run,{
     req(input$r1)
     mode <- input$mode
     r1_path <- input$r1$datapath
     r2_path <- if(!is.null(input$r2)) input$r2$datapath else NULL
     outdir <- file.path(tempdir(), paste0("trim_",format(Sys.time(),"%Y%m%d_%H%M%S")))
      
      dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
      
      log_file <- file.path(outdir, paste0("trimmomatic_log_",format(Sys.time(),"%Y%m%d_%H%M%S"),".txt"))
      
      log_path(log_file)
      
      cat("",file=log_file)
      
      trimmomatic_jar <- input$trimmomatic_jar$datapath
      
      if(is.null(trimmomatic_jar) || !file.exists(trimmomatic_jar)){
        showNotification("Arquivo do Trimmomatic não encontrado.",type="error")
        append_log(log_file,"Arquivo do Trimmomatic não encontrado.")
        return()
      }
      if(input$adapter_choice=="custom" && nzchar(input$custom_adapter)){
       adapters_file <- input$custom_adapter
      }else{
        adapters_file <- file.path(
          "data/adapters",
          input$adapter_choice
        )
      }
      sw <- paste0("SLIDINGWINDOW:", input$window_size, ":", input$qual_cut)
      minlen <- paste0( "MINLEN:", input$minlen )
      leading <- paste0("LEADING:", input$leading )
      trailing <- paste0("TRAILING:", input$trailing )
      
      illum_clip <- paste0("ILLUMINACLIP:", adapters_file, ":2:30:10" )
      
# SINGLE END  
      if(mode=="SE"){
        out_se <- file.path(outdir,"trimmed_SE.fastq.gz")
        args <- c(
        "-jar",
        shQuote(trimmomatic_jar),"SE","-phred33",shQuote(r1_path),
        shQuote(out_se),illum_clip,leading,trailing,
        sw,minlen
        )
        append_log(log_file,"Executando Trimmomatic (SE)...")
        
        trim_metricas <- measure_execution("Trimagem", {
         resultado <- tryCatch({
         out <- system2("java", args=args, stdout=TRUE, stderr=TRUE)
         append_log(log_file,paste(out,collapse="\n"))
            
          if(!file.exists(out_se))
              stop("Arquivo trimmed_SE não foi criado.")
            TRUE
            
          },error=function(e){
            append_log(log_file,e$message)
            showNotification(e$message,type="error")
            FALSE
          })
         
         return(resultado)
        })
        
        print_metrics(trim_metricas)
        
        shinyjs::html(
          "qa_output",
          paste0(
            '<b style="color: #31231a">Trimagem finalizada!</b><br>',
            'Tempo de execução: ', round(trim_metricas$tempo, 2), ' s<br>',
            'Pico de memória RAM: ', round(trim_metricas$ram, 2), ' MiB'
          )
        )
        
        if(!res){
        trimmed_paths(NULL)
        return()
        }
        
        trimmed_paths(list(single_trimmed=out_se, outdir=outdir))
        
        stats <- tryCatch({
        raw <- read_sample_fastq(r1_path)
        trim <- read_sample_fastq(out_se)
        dados <- calc_stats(raw,trim)
        dados$tipo <- c("Raw","Trimmed")
        dados
        },error=function(e){
        append_log(log_file,e$message)
        showNotification(e$message,type="error")
        NULL
        })
        
      } else{
# PAIRED END 
        req(r2_path)
        r1_paired <- file.path(outdir,"R1_paired.fastq.gz")
        r1_unpaired <- file.path(outdir,"R1_unpaired.fastq.gz")
        r2_paired <- file.path(outdir,"R2_paired.fastq.gz")
        r2_unpaired <- file.path(outdir,"R2_unpaired.fastq.gz")
        
        args <- c("-jar",
          shQuote(trimmomatic_jar),"PE","-phred33",shQuote(r1_path),shQuote(r2_path),
          shQuote(r1_paired),shQuote(r1_unpaired),shQuote(r2_paired), shQuote(r2_unpaired),
          illum_clip,leading,trailing,sw,minlen)
        
        append_log(log_file,"Executando Trimmomatic (PE)...")
        
        trim_metricas <- measure_execution("Trimagem", {
          resultado <- tryCatch({
            out <- system2("java", args=args, stdout=TRUE, stderr=TRUE)
            
            append_log(log_file,paste(out,collapse="\n") )
            
            if(!file.exists(r1_paired))
              stop("R1_paired não encontrado.")
            
            if(!file.exists(r2_paired))
              stop("R2_paired não encontrado.")
            TRUE
           },error=function(e){
            append_log(log_file,e$message)
            showNotification(e$message,type="error")
            FALSE
          })
          
          return(resultado)
          
        })
        
        print_metrics(trim_metricas)
        
        if(!resultado){
          trimmed_paths(NULL)
          return()
        }
        trimmed_paths(list(r1_paired = r1_paired, r2_paired = r2_paired,
                           r1_unpaired = r1_unpaired, r2_unpaired = r2_unpaired,
          outdir = outdir))
        
        stats <- tryCatch({
          raw1 <- read_sample_fastq(r1_path)
          raw2 <- read_sample_fastq(r2_path)
          trim1 <- read_sample_fastq(r1_paired)
          trim2 <- read_sample_fastq(r2_paired)
          tibble( 
            lado = c("R1 Raw", "R2 Raw","R1 Trimmed","R2 Trimmed"),
            n_reads = c(length(raw1), length(raw2), length(trim1), length(trim2)),
            mean_length = c(mean(width(sread(raw1))), mean(width(sread(raw2))),
                            mean(width(sread(trim1))), mean(width(sread(trim2))))
            )
          
        },error = function(e){
          append_log(log_file, e$message)
          showNotification(e$message,type="error")
          NULL
        })
        
      }

      output$stats_table <- renderTable({
        req(stats)
        stats
      }, digits = 0)
      
      output$qual_plot_ui <- renderUI({
        req(stats)
        plotOutput(session$ns("qual_plot_render"), height = "360px")
      })
      output$qual_plot_render <- renderPlot({
        if(mode == "SE"){
          fq_raw  <- read_sample_fastq(r1_path)
          fq_trim <- read_sample_fastq(trimmed_paths()$single_trimmed)
        }else{
          fq_raw  <- read_sample_fastq(r1_path)
          fq_trim <- read_sample_fastq(trimmed_paths()$r1_paired)
       }
        if(length(fq_trim) == 0){
          return(NULL)
        }
        mean_quality_by_cycle <- function(fq){
          Q <- as(quality(fq), "matrix")
          data.frame(pos = seq_len(ncol(Q)),meanQ = colMeans(Q, na.rm = TRUE))
          }
        mq_raw <- mean_quality_by_cycle(fq_raw)
        mq_trim <- mean_quality_by_cycle(fq_trim)
        ggplot() + geom_line( data = mq_raw, aes(pos, meanQ), colour = "blue", linewidth = 1, linetype = 2
          ) + geom_line( data = mq_trim, aes(pos, meanQ), colour = "red", linewidth = 1
          ) + labs( title = paste("Qualidade média -", mode), x = "Posição da base", y = "Qualidade média (Phred)"
          ) + theme_minimal()
        })
       append_log( log_file, paste( "\nTrimagem finalizada.\nArquivos em:", outdir))
      })
     
# Download do log

    output$download_log_ui <- renderUI({
       req(log_path())
       downloadButton(session$ns("download_log"),"Download log (.txt)", class = "btn-trim-download")
      })
     output$download_log <- downloadHandler( filename = function(){ 
       basename(log_path())
      }, content = function(file){
         file.copy(
           log_path(),
           file,
           overwrite = TRUE
         )
       }
     )
     
# Downloads PE

     output$download_r1_paired <- downloadHandler( filename = function(){
         basename(trimmed_paths()$r1_paired)
        },
       content = function(file){
         file.copy(
           trimmed_paths()$r1_paired,
           file,
           overwrite = TRUE )
         }
       )
     output$download_r2_paired <- downloadHandler(filename = function(){
        basename(trimmed_paths()$r2_paired)
      },
       content = function(file){
         file.copy(
           trimmed_paths()$r2_paired,
           file,
           overwrite = TRUE )
      }
     )
# Download SE
     
     output$download_single_trimmed <- downloadHandler(filename = function(){
       basename(trimmed_paths()$single_trimmed)
     },
      content = function(file){
         file.copy(
           trimmed_paths()$single_trimmed,
           file,
           overwrite = TRUE)
         
       }
     )
   })
 }
# -------------------------------------------
# Carregamento das bibliotecas, funções e objetos necessários
# -------------------------------------------
source("scripts/instalar_pacotes.R")
cran_pkgs <- c("reshape2", "dplyr", "ggplot2", "scales", "plotly")
bioc_pkgs <- c("ShortRead", "Biostrings")
instalar_pacotes(cran_pkgs, install.packages)
instalar_pacotes(bioc_pkgs, BiocManager::install)

library(ShortRead)    
library(Biostrings)    
library(reshape2)  
library(dplyr)         
library(ggplot2)      
library(scales)        
library(plotly)

# -------------------------------------------
# Função para verificar a existência de adaptadores
# Param -  caminho_fastq: caminho para o arquivo .fastq
# Param -  paleta_cores: string com nome da paleta escolhida pelo usuario
# Return - lista_plots: lista nomeada com plot estático e plot interativo
# -------------------------------------------
plotAdapterContamination <- function(caminho_fastq, paleta_cores="viridis") {
  
  # Função auxiliar para construir dataframe a partir de um caminho para fastq
  constroi_df <- function(caminho_fastq){
    stream <- FastqStreamer(caminho_fastq)
    fq <- yield(stream)
    reads <- sread(fq)
    
    # Para cada adaptador, um vetor com 0 ou 1 por read
    adapter_matriz <- sapply(adapter_fasta, function(adapter_seq) {
      as.integer(vcountPattern(adapter_seq, reads) > 0)
    })
    
    # Adicionar index dos reads
    adapter_df <- data.frame(Read = 1:length(reads), adapter_matriz)
    
    # Tamanho dos reads   
    tamanho_reads <- nchar(as.character(sread(fq)))  
    final_reads <- cumsum(tamanho_reads)
    inicio_reads <- c(1, head(final_reads + 1, -1))
    adapter_df$Inicio <- inicio_reads
    adapter_df$Fim <- final_reads
    
    # Reorganizar a df de formato wide para long: uma linha por read por adaptador
    adapter_df_long <- melt(adapter_df, id.vars = c("Inicio", "Fim", "Read"),
                            variable.name = "Adaptador", value.name = "Hit")
    
    # Soma cumulativa para proporção dos adaptadores
    adapter_df_long <- adapter_df_long %>%
      dplyr::group_by(Adaptador) %>%
      dplyr::arrange(Inicio) %>%
      dplyr::mutate(
        CumHits = cumsum(Hit),
        Prop = CumHits / max(Read)
      )
    
    return(adapter_df_long)
  }
  
  # Ler arquivo de adaptadores
  adapter_fasta <- readDNAStringSet("data/adapters/adapters.fasta")
  
  # Se há apenas um arquivo fastq
  if (is.character(caminho_fastq) && length(caminho_fastq) == 1) {
    all_adapter_data <- constroi_df(caminho_fastq)
  # Mais de um arquivo
  } else if (is.character(caminho_fastq) && length(caminho_fastq) > 1) {
    
    # Juntar dados de todos os arquivos
    all_adapter_data <- data.frame()
    
    for (fastq in caminho_fastq) {
      adapter_df_long <- constroi_df(fastq)
      all_adapter_data <- rbind(all_adapter_data, adapter_df_long)
    }
  }  
    
  # Separar entre adaptadores com hit e sem hit
  adapter_hit_info <- all_adapter_data %>%
                      dplyr::group_by(Adaptador) %>%
                      dplyr::summarise(has_hits = any(Hit > 0), .groups = "drop")
  
  # Com hit
  hit_adapters <- adapter_hit_info$Adaptador[adapter_hit_info$has_hits]
  adapter_com_hits <- all_adapter_data %>%
                       dplyr::filter(Adaptador %in% hit_adapters)
  adapter_com_hits$Adaptador <- factor(adapter_com_hits$Adaptador)
  
  # Checa se houve hits
  houve_hits <- any(adapter_com_hits$Prop > 0)
  if (houve_hits) {
    n_cores <- length(unique(adapter_com_hits$Adaptador))
    cores <- viridis::viridis(n_cores, option = paleta_cores)
    
    max_y <- max(adapter_com_hits$Prop)
    top_break <- ceiling(max_y * 20) / 20
    breaks_y <- seq(0, top_break, by = 0.05)
      
    # Fazer plot estatico
    p_estatico <- ggplot() +
      geom_line(data = adapter_com_hits,
                aes(x = Inicio, y = Prop, group = Adaptador, color = Adaptador),
                alpha = 0.5, linewidth = 2, show.legend = TRUE) +
      geom_point(data = adapter_com_hits,
                 aes(x = Inicio, y = Prop, color = Adaptador, shape = Adaptador),
                 size = 3, alpha = 0.5) +
      scale_color_manual(values = cores) +
      scale_y_continuous(
        limits = c(0, top_break),
        breaks = breaks_y,
        labels = scales::percent_format(accuracy = 1)
      )
    
    # Fazer plot interativo
    
    # Cores
    adapter_niveis <- unique(adapter_com_hits$Adaptador)
    adapter_com_hits <- adapter_com_hits %>%
      mutate(Cor = cores[match(Adaptador, adapter_niveis)])
    
    # Marcadores
    simbolos_marcadores <- c("circle", "square", "diamond", "cross", "x",
                             "triangle-up", "triangle-down")
    adaptadores <- unique(adapter_com_hits$Adaptador)
    simbolos_usados <- simbolos_marcadores[seq_along(adaptadores)]
    
    # Plot
    p_interativo <- plot_ly()
    for (i in seq_along(adaptadores)) {
      adaptador <- adaptadores[i]
      dados_filtrados <- adapter_com_hits %>% filter(Adaptador == adaptador)
      p_interativo <- p_interativo %>%
        add_trace(
          data = dados_filtrados,
          x = ~Inicio,
          y = ~Prop,
          type = 'scatter', mode = 'lines+markers',
          name = adaptador,
          line = list(color = unique(dados_filtrados$Cor), width = 5),
          marker = list(color = unique(dados_filtrados$Cor),
                        symbol = simbolos_usados[i], size = 8),
          opacity = 0.5
        )
    }
    
  # Sem hits
  } else {
    adapter_sem_hits <- all_adapter_data %>%
      dplyr::filter(!Adaptador %in% hit_adapters)
    
    # Plot sem hits
    p_estatico <- ggplot() +
      geom_line(data = adapter_sem_hits,
                aes(x = Inicio, y = 0, group = Adaptador),
                color = "grey70", alpha = 0.5, linewidth = 0.5,
                show.legend = FALSE) +
      scale_y_continuous(
        limits = c(0, NA),
        breaks = 0,       
        labels = scales::percent_format(accuracy = 1)
      )
    
    # Cria gráfico interativo
    p_interativo <- ggplotly(p_estatico)
  }
  
  # Ajusta plot estatico
  p_estatico <- p_estatico +
    labs(
      title = if (houve_hits) "Contaminação Cumulativa de Adaptadores" else 
        "Contaminação Cumulativa de Adaptadores (sem hits detectados)",
      x = "Posição (par de bases)",
      y = "Proporção de reads contaminados"
    ) +
    theme(
      legend.position = "right",
      legend.title = element_text(),
      panel.background = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(color = "grey")
    )
  
  # Ajusta plot interativo
  p_interativo <- p_interativo %>%
                  layout(
                    plot_bgcolor = "white",  
                    paper_bgcolor = "white",  
                    title = list(
                      text = if (houve_hits) "Contaminação Cumulativa de Adaptadores" else 
                        "Contaminação Cumulativa de Adaptadores (sem hits detectados)",
                      font = list(
                        size = 16,
                        color = "black"
                      ),
                      xanchor = "left",
                      x = 0.07,
                      y = 0.98
                    ),
                    xaxis = list(
                      title = "Posição (par de bases)",
                      titlefont = list(
                        size = 14,
                        color = "black"
                      ),
                      showgrid = FALSE,      
                      zeroline = FALSE,   
                      showline = TRUE,
                      linecolor = "gray",      
                      linewidth = 1         
                    ),
                    yaxis = list(
                      title = "Proporção de reads contaminados",
                      titlefont = list(
                        size = 14,
                        color = "black"
                      ),
                      showgrid = FALSE,      
                      zeroline = FALSE,
                      showline = TRUE,
                      linecolor = "gray",    
                      linewidth = 1
                    ),
                    legend = list(
                      title = list(text = "Adaptador"),
                      font = list(
                        color = "black"  
                      ),
                      x = 1,        
                      y = 0.5,     
                      xanchor = "left", 
                      yanchor = "middle" 
                    )
                  )
  
  # Retorna lista com os dois gráficos (estático e interativo)
  lista_plots <- list(p_estatico = p_estatico, p_interativo = p_interativo)
  
  return(lista_plots)
}

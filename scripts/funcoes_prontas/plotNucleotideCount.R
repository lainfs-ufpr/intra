# -------------------------------------------
# Carregamento das bibliotecas, funções e objetos necessários
# -------------------------------------------
source("scripts/instalar_pacotes.R")
cran_pkgs <- c("tidyverse", "dplyr", "ggplot2", "tidyr", "scales", "plotly")
bioc_pkgs <- c("ShortRead")
instalar_pacotes(cran_pkgs, install.packages)
instalar_pacotes(bioc_pkgs, BiocManager::install)

library(ShortRead)    
library(tidyverse)
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(stats)
library(plotly)

# -------------------------------------------
# Função para verificar a frequência das bases por read
# Param -  caminho_fastq: caminho para o arquivo .fastq
# Param -  paleta_cores: string com nome da paleta escolhida pelo usuario
# Param -  nomes_arquivos: nomes originais dos arquivos de entrada
# Return - lista_plots: lista nomeada com plot estático e plot interativo
# -------------------------------------------
plotNucleotideCount <- function(caminho_fastq, paleta_cores="viridis", nomes_arquivos) {
  
  # Um arquivo
  if (is.character(caminho_fastq) && length(caminho_fastq) == 1) {
    
    # Ler arquivo
    fq <- ShortRead::FastqStreamer(caminho_fastq)
    reads <- as.character(ShortRead::sread(fq))
    
    # Realizar contagens
    contagens <- lapply(reads, function(seq) {
      table(factor(strsplit(seq, "")[[1]], levels = c("A", "T", "C", "G", "N")))
    })
    
    # Organizar dataframe
    df_contagens <- do.call(rbind, contagens)
    rownames(df_contagens) <- paste0("Read", seq_along(reads))
    df_contagens <- as.data.frame(df_contagens)
    
    df_frequencias <- df_contagens %>%
      tibble::rownames_to_column(var = "Sample") %>%
      tidyr::pivot_longer(cols = A:N, names_to = "Base", values_to = "Count") %>%
      dplyr::mutate(Base = factor(Base, levels = c("A", "T", "C", "G", "N"))) %>%
      dplyr::group_by(Sample) %>%
      dplyr::mutate(Frequency = Count / sum(Count)) %>%
      dplyr::ungroup()
    
    df_frequencias$Arquivo <- rep(basename(caminho_fastq), nrow(df_frequencias))
    
    # Ajusta nomes dos arquivos
    df_frequencias$Arquivo <- nomes_arquivos[
      match(df_frequencias$Arquivo,
            unique(df_frequencias$Arquivo))
    ]
    
    # Gerar cores suficientes para as bases (5 cores)
    n_cores <- length(levels(df_frequencias$Base))
    cores <- viridis::viridis(n_cores, option = paleta_cores)
    
    # Expandir se a paleta for menor que n_cores
    if (length(cores) < n_cores) {
      cores <- rep(cores, length.out = n_cores)
    }
    
    # Montar plot
    p_estatico <- ggplot2::ggplot(df_frequencias, ggplot2::aes(x = Base,
                                                                y = Frequency,
                                                                fill = Base)) +
      ggplot2::geom_boxplot(alpha = 0.9, outlier.shape = NA, color = "black") +
      ggplot2::geom_jitter(width = 0.2, size = 1, alpha = 0.5) +
      ggplot2::scale_y_continuous(trans = scales::pseudo_log_trans(sigma = 1)) +
      ggplot2::scale_fill_manual(values = cores) +
      ggplot2::labs(
        title = "Distribuição da Frequência de Bases por Read",
        x = "Base",
        y = "Frequência (pseudo-log)"
      ) +
      ggplot2::theme(
        legend.position = "none",
        panel.background = ggplot2::element_blank(),
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.line = ggplot2::element_line(color = "grey")
      )
  
  # Mais de um arquivo  
  } else {
    # Vetor de arquivos
    lista_dfs <- lapply(caminho_fastq, function(arquivo) {
      stream <- FastqStreamer(arquivo)
      fq <- yield(stream)
      reads <- as.character(sread(fq))
      
      contagens <- lapply(reads, function(seq) {
        table(factor(strsplit(seq, "")[[1]], levels = c("A", "T", "C", "G", "N")))
      })
      
      # Organizar dataframe
      df_contagens <- do.call(rbind, contagens)
      df_contagens <- as.data.frame(df_contagens)
      
      df_frequencias <- df_contagens %>%
        pivot_longer(cols = A:N, names_to = "Base", values_to = "Count") %>%
        group_by(Base) %>%
        summarise(MeanFrequency = mean(Count / rowSums(df_contagens))) %>%
        mutate(Arquivo = basename(arquivo))
      
      return(df_frequencias)
    })
    
    df_todos <- do.call(rbind, lista_dfs)
    df_todos$Base <- factor(df_todos$Base, levels = c("A", "T", "C", "G", "N"))
    
    # Gerar cores suficientes para as bases (5 cores)
    n_bases <- length(unique(df_todos$Arquivo))
    cores <- viridis::viridis(n_bases, option = paleta_cores)
    
    # Montar plot
    p_estatico <- ggplot(df_todos, aes(x = Base, y = MeanFrequency,
                                        color = Arquivo, group = Arquivo)) +
      geom_point(size = 2, alpha = 0.5, position = position_dodge(width = 0.4)) +
      scale_color_manual(values = cores) +
      labs(
        title = "Média da Frequência de Bases",
        x = "Base",
        y = "Frequência Média"
      ) +
      theme(legend.position = "right",
            panel.background = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.line = element_line(color = "grey"))
  }
  
  
  # Cria gráfico interativo
  p_interativo <- ggplotly(p_estatico)
  p_interativo <- p_interativo %>%
                  layout(
                    title = list(
                      font = list(
                        size = 16,
                        color = "black"
                      )
                    ),
                    xaxis = list(
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
                      titlefont = list(
                        size = 14,
                        color = "black"
                      ),
                      showgrid = FALSE,      
                      zeroline = FALSE,
                      showline = TRUE,
                      linecolor = "gray",    
                      linewidth = 1
                    )
                  )
  
  # Retorna lista com os dois gráficos (estático e interativo)
  lista_plots <- list(p_interativo = p_interativo, p_estatico = p_estatico)
  
  return(lista_plots)
}

# -------------------------------------------
# Carregamento das bibliotecas, funções e objetos necessários
# -------------------------------------------
source("scripts/instalar_pacotes.R")
cran_pkgs <- c("reshape2", "dplyr")
bioc_pkgs <- c("ShortRead", "Biostrings")
instalar_pacotes(cran_pkgs, install.packages)
instalar_pacotes(bioc_pkgs, BiocManager::install)

library(ShortRead)    
library(Biostrings)    
library(reshape2)  
library(dplyr)          

# -------------------------------------------
# Função para verificar a existência de adaptadores
# Param -  caminho_fastq: caminho para o arquivo .fastq
# Return - p_adapter: plot com proporção cumulativa de adaptadores
# -------------------------------------------
tableAdapterContamination <- function(caminho_fastq){
  
  constroi_df <- function(caminho_fastq){
    # Ler sequências do fastq
    stream <- FastqStreamer(caminho_fastq)
    fq <- yield(stream)
    reads <- sread(fq)
    
    # Para cada adaptador, um vetor com 0 ou 1 por read
    presenca_adapters <- sapply(adapter_fasta, function(adapter_seq) {
      as.integer(vcountPattern(adapter_seq, reads) > 0)
    })
    
    if (length(colnames(presenca_adapters)[colSums(presenca_adapters) > 0]) == 0){
      adapters_presentes <- "Sem hits"
    } else {
      adapters_presentes <- colnames(presenca_adapters)[colSums(presenca_adapters) > 0]
    }

    # Montar a linha da tabela
    df_adapters <- data.frame(
                          Arquivo = basename(caminho_fastq),
                          Adaptador = paste(adapters_presentes, collapse = ", ")
                        )
    return(df_adapters)
  }
  
  # Ler arquivo de adaptadores
  adapter_fasta <- readDNAStringSet("data/adapters/adapters.fasta")

  if (is.character(caminho_fastq) && length(caminho_fastq) == 1) {
    df_adapters_final <- constroi_df(caminho_fastq)
  } else {
    df_adapters_final <- data.frame(Arquivo = c(), Adaptador = c())
    # colnames(df_adapters_final) <- c("Arquivo", "Adaptador")
    for (fastq in caminho_fastq) {
      df_adapter <- constroi_df(fastq)
      df_adapters_final <- rbind(df_adapters_final, df_adapter)
    }
  }
  return(df_adapters_final)
}

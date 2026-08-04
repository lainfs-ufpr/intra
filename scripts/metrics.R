measure_execution <- function(nome, expr) {
  
  inicio <- Sys.time()
  
  ram <- peakRAM::peakRAM({
    valor <- force(expr)
  })
  
  fim <- Sys.time()
  
  list(
    nome = nome,
    resultado = valor,
    tempo = as.numeric(difftime(fim, inicio, units = "secs")),
    ram = ram$Peak_RAM_Used_MiB[1]
  )
}

print_metrics <- function(m) {
  
  cat("\n===================================\n")
  cat("RESUMO DE DESEMPENHO\n")
  cat("===================================\n")
  
  cat(m$nome, "\n", sep = "")
  cat("Tempo:", round(m$tempo, 2), "s\n")
  cat("Pico de memória RAM:", round(m$ram, 2), "MiB\n")
  
  cat("===================================\n")
}
$body = @{
  query = '10 notícias mais relevantes de inteligência artificial e tecnologia nas últimas 24 horas'
  limit = 10
  kind = 'news'
  timelimit = 'd'
  language = 'pt-BR'
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri 'http://localhost:8000/research' -ContentType 'application/json' -Body $body | ConvertTo-Json -Depth 10

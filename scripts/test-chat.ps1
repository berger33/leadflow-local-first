$body = @{
  message = 'Explique em poucas linhas como este sistema funciona.'
  chat_id = 'local-test'
  use_web = $false
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri 'http://localhost:8000/chat' -ContentType 'application/json' -Body $body | ConvertTo-Json -Depth 8

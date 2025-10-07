```bash
#!/data/data/com.termux/files/usr/bin/bash
# sms_api_minimal_busybox.sh
# Versão mínima de "API" HTTP para Termux usando busybox nc
# Requisitos:
#   pkg install termux-api busybox
#
# Uso:
#   chmod +x sms_api_minimal_busybox.sh
#   ./sms_api_minimal_busybox.sh
#
# Endpoint:
#   POST /send
#   Headers: Authorization: Bearer SEU_TOKEN
#   Body JSON: {"to":"+5511999998888","text":"mensagem"}
#
# Troque API_TOKEN abaixo por um token forte antes de usar em produção.

PORT=8080
API_TOKEN="TESTE123456"   # <- troque por token forte

command -v termux-sms-send >/dev/null 2>&1 || { echo "Instale termux-api (pkg install termux-api)"; exit 1; }
command -v busybox >/dev/null 2>&1 || { echo "Instale busybox (pkg install busybox)"; exit 1; }

echo "API mínima iniciada com busybox. Escutando na porta $PORT..."
echo "Token atual: $API_TOKEN"
echo "CTRL+C para parar."

while true; do
  # Captura a requisição (headers + body) em uma variável
  REQ="$(busybox nc -l -p $PORT -q 1 2>/dev/null || true)"

  # Se nada recebido, continuar
  if [ -z "$REQ" ]; then
    sleep 0.1
    continue
  fi

  # Extrai primeira linha (request line), headers e body
  REQ_LINE="$(echo "$REQ" | head -n1)"
  METHOD="$(echo "$REQ_LINE" | awk '{print $1}')"
  PATH="$(echo "$REQ_LINE" | awk '{print $2}')"

  # Extrai Authorization header (caso exista)
  AUTH_LINE="$(echo "$REQ" | grep -i '^Authorization:' | head -n1)"
  AUTH_TOKEN="$(echo "$AUTH_LINE" | sed -E 's/^[Aa]uthorization:[[:space:]]*[Bb]earer[[:space:]]*(.*)/\1/')"

  # Extrai body: assume que o body vem após a primeira linha em branco
  BODY="$(echo "$REQ" | awk 'BEGIN{found=0} { if(found==1) print $0 } /^$/ {found=1}')"
  # Remove possíveis linhas vazias extras e trim
  BODY="$(echo "$BODY" | sed '/^[[:space:]]*$/d' | tr -d '\r')"

  # Valida autenticação
  if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" != "$API_TOKEN" ]; then
    BODY_OUT='{"error":"unauthorized"}'
    printf "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nContent-Length: ${#BODY_OUT}\r\n\r\n$BODY_OUT" | busybox nc -l -p $PORT -q 1 >/dev/null 2>&1 || true
    continue
  fi

  # Rota esperada
  if [ "$METHOD" != "POST" ] || [ "$PATH" != "/send" ]; then
    BODY_OUT='{"error":"not_found"}'
    printf "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nContent-Length: ${#BODY_OUT}\r\n\r\n$BODY_OUT" | busybox nc -l -p $PORT -q 1 >/dev/null 2>&1 || true
    continue
  fi

  # Extrai "to" e "text" do body (padrão simples, sem escapes complexos)
  TO="$(echo "$BODY" | sed -E 's/.*"to"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  TEXT="$(echo "$BODY" | sed -E 's/.*"text"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

  if [ -z "$TO" ] || [ -z "$TEXT" ]; then
    BODY_OUT='{"error":"missing_to_or_text"}'
    printf "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: ${#BODY_OUT}\r\n\r\n$BODY_OUT" | busybox nc -l -p $PORT -q 1 >/dev/null 2>&1 || true
    continue
  fi

  # Enviar SMS via termux-sms-send
  termux-sms-send -n "$TO" "$TEXT"
  RC=$?

  if [ $RC -eq 0 ]; then
    BODY_OUT="{\"status\":\"queued\",\"to\":\"$TO\"}"
    printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${#BODY_OUT}\r\n\r\n$BODY_OUT" | busybox nc -l -p $PORT -q 1 >/dev/null 2>&1 || true
  else
    BODY_OUT="{\"status\":\"error\",\"code\":$RC}"
    printf "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: ${#BODY_OUT}\r\n\r\n$BODY_OUT" | busybox nc -l -p $PORT -q 1 >/dev/null 2>&1 || true
  fi

done
```

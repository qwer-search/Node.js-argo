#!/usr/bin/env bash
export NEZHA_SERVER=${NEZHA_SERVER:-'nz.abcd.com'}
export NEZHA_PORT=${NEZHA_PORT:-'5555'} # 当端口为443时，自动开启tls
export NEZHA_KEY=${NEZHA_KEY:-'abcdefghijk'}
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}
export ARGO_AUTH=${ARGO_AUTH:-''}
export UUID=${UUID:-'19bb8322-a565-4956-9696-a6c0bbf0408c'}
export CFIP=${CFIP:-'skk.moe'}
export NAME=${NAME:-'Vls'}

# 生成xri配置文件
generate_config() {
  cat > config.json << EOF
{
    "log":{
        "access":"/dev/null",
        "error":"/dev/null",
        "loglevel":"none"
    },
    "inbounds":[
        {
            "port":8080,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "flow":"xtls-rprx-vision"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/vless",
                        "dest":3002
                    },
                    {
                        "path":"/vmess",
                        "dest":3003
                    },
                    {
                        "path":"/trojan",
                        "dest":3004
                    },
                    {
                        "path":"/shadowsocks",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/vless"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/vmess"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/trojan"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/shadowsocks"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        }
    ],
    "dns":{
        "servers":[
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds":[
        {
            "protocol":"freedom"
        },
        {
            "tag":"WARP",
            "protocol":"wireguard",
            "settings":{
                "secretKey":"YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
                "address":[
                    "172.16.0.2/32",
                    "2606:4700:110:8a36:df92:102a:9602:fa18/128"
                ],
                "peers":[
                    {
                        "publicKey":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "allowedIPs":[
                            "0.0.0.0/0",
                            "::/0"
                        ],
                        "endpoint":"162.159.193.10:2408"
                    }
                ],
                "reserved":[78, 135, 76],
                "mtu":1280
            }
        }
    ],
    "routing":{
        "domainStrategy":"AsIs",
        "rules":[
            {
                "type":"field",
                "domain":[
                    "domain:openai.com",
                    "domain:ai.com"
                ],
                "outboundTag":"WARP"
            }
        ]
    }
}
EOF
}
generate_config
sleep 3

cleanup_files() {
  rm -rf boot.log list.txt 
}
cleanup_files
sleep 2

argo_type() {
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    echo "ARGO_AUTH or ARGO_DOMAIN is empty, use Quick Tunnels"
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > tunnel.json
    cat > tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< $ARGO_AUTH)
credentials-file: ./tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:8080
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    echo "ARGO_AUTH Mismatch TunnelSecret"
  fi
}
argo_type
sleep 3

run() {
  if [ "$NEZHA_PORT" = 443 ]; then
    NEZHA_TLS="--tls"
  else
    NEZHA_TLS=""
  fi
  if [ -e swith ]; then
  chmod 775 swith
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
    nohup ./swith -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
    keep1="nohup ./swith -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &"
    fi
  fi

  if [ -e web ]; then
  chmod 775 web
    nohup ./web -c ./config.json >/dev/null 2>&1 &
    keep2="nohup ./web -c ./config.json >/dev/null 2>&1 &"
  fi

  if [ -e server ]; then
  chmod 775 server
if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
  args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info run --token ${ARGO_AUTH}"
elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
  args="tunnel --edge-ip-version auto --config tunnel.yml run"
else
  args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:8080"
fi
nohup ./server $args >/dev/null 2>&1 &
keep3="nohup ./server $args >/dev/null 2>&1 &"
  fi
} 

run
sleep 8

function get_argo_domain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN"
  else
    cat boot.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}'
  fi
}

isp=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18"-"$30}' | sed -e 's/ /_/g')
sleep 2

generate_links() {
  argo=$(get_argo_domain)
  sleep 2

  VMESS="{ \"v\": \"2\", \"ps\": \"${NAME}-${isp}\", \"add\": \"${CFIP}\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argo}\", \"path\": \"/vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"${argo}\", \"alpn\": \"\" }"

  cat > list.txt <<EOF
vless://${UUID}@${CFIP}:443?encryption=none&security=tls&sni=${argo}&type=ws&host=${argo}&path=%2Fvless?ed=2048#${NAME}-${isp}

vmess://$(echo "$VMESS" | base64 -w0)

trojan://${UUID}@${CFIP}:443?security=tls&sni=${argo}&type=ws&host=${argo}&path=%2Ftrojan?ed=2048#${NAME}-${isp}
EOF
  cat list.txt
base64 -w0 list.txt > sub.txt
  echo -e "files are saved successfully"
}
generate_links

cleanup_files() {
  sleep 120  
  rm -rf boot.log list.txt config.json
}
cleanup_files

function start_swith_program() {
if [ -n "$keep1" ]; then
  if [ -z "$pid" ]; then
    echo "course'$program'Not running, starting..."
    eval "$command"
  else
    echo "course'$program'running，PID: $pid"
  fi
else
  echo "course'$program'No need"
fi
}

function start_web_program() {
  if [ -z "$pid" ]; then
    echo "course'$program'Not running, starting..."
    eval "$command"
  else
    echo "course'$program'running，PID: $pid"
  fi
}

function start_server_program() {
  if [ -z "$pid" ]; then
    echo "'$program'Not running, starting..."
    cleanup_files
    sleep 2
    eval "$command"
    sleep 5
    generate_links
    sleep 3
  else
    echo "course'$program'running，PID: $pid"
  fi
}

function start_program() {
  local program=$1
  local command=$2

  pid=$(pidof "$program")

  if [ "$program" = "swith" ]; then
    start_swith_program
  elif [ "$program" = "web" ]; then
    start_web_program
  elif [ "$program" = "server" ]; then
    start_server_program
  fi
}

programs=("swith" "web" "server")
commands=("$keep1" "$keep2" "$keep3")

while true; do
  for ((i=0; i<${#programs[@]}; i++)); do
    program=${programs[i]}
    command=${commands[i]}

    start_program "$program" "$command"
  done
  sleep 180
done

# 每10秒自动删除垃圾文件
generate_autodel() {
  cat > autodel.sh <<EOF
while true; do
  rm -rf /app/.git
  sleep 180
done
EOF
}
generate_autodel
[ -e delete.sh ] && bash autodel.sh

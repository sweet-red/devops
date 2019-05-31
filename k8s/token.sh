# 创建 TLS Bootstrapping Token
#BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
BOOTSTRAP_TOKEN=0fb61c46f8991b718eb38d27b605b008

cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

mkdir /tmp/ca

cd /tmp/ca

cfssl gencert \
   -initca \
   /tmp/kanku/configs/cfssl/ca-csr.json | cfssljson -bare ca

cfssl gencert \
   -loglevel=0 \
   -ca=ca.pem \
   -ca-key=ca-key.pem \
   -config=/tmp/kanku/configs/cfssl/ca-config.json \
   -cn="bs-monitor.suse.de" \
   -hostname="bs-monitor.nue.suse.de" \
   -profile=kubernetes \
   /tmp/kanku/configs/cfssl/generic-csr.json | cfssljson -bare bs-monitor.suse.de

# k8s-mini-tool
Simple SH tool for beginners k8s users

You can setup new access to k8s with using .pem file and token(1), delete context(2) or switch context(3), get pods and run commands(4).

Usage:\
sudo chmod+x k8s-mini-tool.sh\
./k8s-mini-tool.sh

default settings:\
CERT=ca-auto.pem\
EDITOR=nano\
CONTAINER=app\
COMMAND="(bash || ash || sh)"

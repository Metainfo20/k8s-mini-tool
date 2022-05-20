# k8s-mini-tool
Simple SH tool for beginners k8s users

You can setup new access to k8s with using .pem file and token(1), delete context(2) or switch context(3), get pods and run commands(4).

Usage:\
sudo chmod+x k8s-mini-tool.sh\
./k8s-mini-tool.sh\

default settings:\
ALLOW_FILE_LOAD=0 - Change to 1 for enable upload local file to pod(50KB max limit)\
USE_COMMAND2=0 - Change to 1 for enable secondary command\
CERT=ca-auto.pem - filename for cert file\
EDITOR=nano - default editor\
CONTAINER=app - pod container\
FILEPATH=app - filepath for upload file in pod\
COMMAND="(bash || ash || sh)" - primary command\
COMMAND2="" - secondary command\

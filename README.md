# k8s-mini-tool
Simple SH tool for k8s users

MAIN MENU:

Selected Context:\
192.168.1.2-stage\
Selected Objects:\
NAMESPACE=stage\
POD=test-pod\
CONTAINER=test-c

1 - Setup New k8s Access\
2 - Delete Context\
3 - Switch Context\
4 - Get New Pod and Run Command\
5 - Get Selected Pod and Run Command\
6 - Edit Deploy File\
7 - Get Files from Pod\
8 - Send Files to Pod
 
Enter your choice:

You can setup new access to k8s with using .pem file and token(1), delete context(2) or switch context(3), get pods and run commands(4), get already selected pod(5), edit deploy file(6), get files from pod(7) or upload to pod(8)

Usage:\
sudo chmod+x k8s-mini-tool.sh\
./k8s-mini-tool.sh

default settings:\
ALLOW_FILE_LOAD=0 - Change to 1 for enable upload local file to pod(50KB max limit)\
USE_COMMAND2=0 - Change to 1 for enable secondary command\
CERT=ca-auto.pem - filename for cert file\
EDITOR=nano - default editor\
CONTAINER=app - pod container\
COMMAND="(bash || ash || sh)" - primary command\
COMMAND2="" - secondary command\

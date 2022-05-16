#!/bin/bash

CERT=ca-auto.pem
EDITOR=nano
CONTAINER=app
COMMAND="(bash || ash || sh)"

f_sep(){
echo "---------------------------"
}

f_text(){
echo -e "\033[32m$1\033[0m"
}

f_text_bl(){
echo -e "\033[1;36m$1\033[0m"
}

f_warning_text(){
echo -e "\033[31m$1\033[0m"
}

f_get_contexts(){
f_text "Get all contexts:"
kubectl config get-contexts
f_sep
}

f_menu_setup_access(){
f_text_bl "Setup new k8s access";f_sep
f_text "Input token:";read TOKEN
f_text "Input username(for example user-test):";read USERNAME
f_text "Input endpoint(for example, https://192.168.1.2/):";read ENDPOINT
f_text "Input cluster name(for example, $ENDPOINT):";read CLUSTERNAME
f_text "1. set credentials"
kubectl config set-credentials $USERNAME  --token=$TOKEN
f_text "2. create and update $CERT file"
if [ -e $CERT ]
then
    while true; do
    f_warning_text "File $CERT Already exist! Overwrite? (y/n)"; read yn
        case $yn in
            [Yy]* )
            truncate -s 0 $CERT;
            echo "Delete this, insert certificate text here and save" > $CERT;
            $EDITOR $CERT;
            break;;
            [Nn]* )
            f_warning_text "New certificate not set, use existing certificate"
            break;;
            * ) echo "Please answer y (yes) or n (no).";;
        esac
    done
else
    touch $CERT;echo "Delete this, insert certificate text here and save" > $CERT
    $EDITOR $CERT
fi
f_text "3. create cluster $CLUSTERNAME"
kubectl config set-cluster $CLUSTERNAME --certificate-authority=$CERT  --server=$ENDPOINT
f_text "4. set context $USERNAME-$ENDPOINT"
kubectl config set-context $USERNAME-$ENDPOINT --cluster=$CLUSTERNAME --user=$USERNAME
f_text "4. get all contexts"
kubectl config get-contexts
f_text "5. use context $USERNAME-$ENDPOINT"
kubectl config use-context $USERNAME-$ENDPOINT
f_text "6. Get namespaces"
kubectl get ns
}

f_menu_switch_context(){
f_text_bl "Switch k8s context";f_sep
f_get_contexts
f_text "Input NAME context to switch to:";read CONTEXTNAME
kubectl config use-context $CONTEXTNAME
f_get_contexts
}

f_menu_delete_context(){
f_text_bl "Delete k8s context";f_sep
f_get_contexts
f_text "Input NAME context to be deleted:";read CONTEXTNAME
kubectl config unset contexts.$CONTEXTNAME
f_get_contexts
}

f_menu_get_pod(){
f_text_bl "Get pod and run command";f_sep
f_get_contexts
kubectl get ns
while true; do
   f_text "Input NAMESPACE from list for get pods or input ALL for get all pods in all namespaces:"
   read NAMESPACE
   case $NAMESPACE in
       "ALL") kubectl get pods --all-namespaces;;
       "all") kubectl get pods --all-namespaces;;
       "") f_warning_text "Cannot be empty";;
       *) kubectl get pods --namespace $NAMESPACE; f_text "Input PODNAME from list:";read POD;break;;
   esac
done
f_text "Run command $COMMAND in $NAMESPACE $POD $CONTAINER"
kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND"
}

f_menu_choice(){
    while true; do
    f_text_bl "     _                               
 /_ /_/  _   _ _  . _  .  _/_ _  _  /
/\ /_/ _\   / / // / //   /  /_//_// 
                                     "
    f_sep
    echo "1 - Setup new k8s access"
    echo "2 - Delete context"
    echo "3 - Switch context"
    echo "4 - Get pod and run command"
    f_sep
    echo "Enter your choice:";read choice;f_sep
        case $choice in
            "1")
            f_menu_setup_access;;
            "2")
            f_menu_delete_context;;
            "3")
            f_menu_switch_context;;
            "4")
            f_menu_get_pod;;
            "777")
            f_text_bl "v1.0";;
            * ) echo "Please enter valid number or hit CTRL+C for exit.";;
        esac
    done
}

f_menu_choice

#!/bin/bash

ALLOW_FILE_LOAD=0
USE_COMMAND2=0
CERT=ca-auto.pem
EDITOR=nano
CONTAINER=app
FILEPATH=app
COMMAND="(bash || ash || sh)"
COMMAND2=""

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

f_run_command(){
if [ $ALLOW_FILE_LOAD = 1 ]
then
    f_text "Input filename to copy in pod(50kB max):";read FILENAME
    f_write_file_to_pod
fi
f_text "Run command $COMMAND2 $COMMAND in $NAMESPACE $POD $CONTAINER"
if [ "$USE_COMMAND2" = 1 ] && [ "$COMMAND2" != "" ]
then
    kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND2;$COMMAND"
else
    kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND"
fi
}

f_write_file_to_pod() {
    if [ $FILENAME ] && [ -e $FILENAME ]
    then
        FILESIZE=$(wc -c $FILENAME | awk '{print $1}')
        if [ $FILESIZE -lt 51200 ]
        then
            f_text "kubectl cp $FILENAME $NAMESPACE/$POD:/$FILEPATH/$FILENAME -c $CONTAINER"
            while true; do
                read -p "Do you want to send $FILENAME? (y/n)" yn
                case $yn in
                    [Yy]* )
                    kubectl cp $FILENAME $NAMESPACE/$POD:/$FILEPATH/$FILENAME -c $CONTAINER
                    break;;
                    [Nn]* )
                    echo "$FILENAME file was not sent"
                    break;;
                    * ) echo "Please answer y (yes) or n (no)";;
                esac
            done
        fi
    else
        f_warning_text "No file to send or max limit(50kb) reached"
    fi
}

f_get_deploy_status(){
f_text "Current status $DEP $NAMESPACE:"
kubectl get deploy $DEP --namespace $NAMESPACE
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
    f_warning_text "File $CERT Already exist! Create new one? (y/n)"; read yn
        case $yn in
            [Yy]* )
            f_text "Input new filename(for example, ca-auto1.pem):";read CERT;
            if [ -e $CERT ]
            then
                continue
            else
                echo "Delete this, insert certificate text here and save" > $CERT;
                $EDITOR $CERT;
                break;
            fi;;
            [Nn]* )
            f_warning_text "New certificate not set, use existing certificate $CERT"
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
       ALL | all | All) kubectl get pods --all-namespaces;;
       "") f_warning_text "Cannot be empty";;
       *) kubectl get pods --namespace $NAMESPACE 2> k8smt;\
       grep -q -c "No resources found in" k8smt;if [ $? -eq 1 ];\
       then f_text "Input PODNAME from list:";read POD;rm k8smt;break;else \
       echo "No resources found in $NAMESPACE";rm k8smt;continue;fi;;
   esac
done

f_run_command
}

f_menu_edit_deploy(){
f_text_bl "Edit Deploy file";f_sep
f_get_contexts
kubectl get ns
while true; do
   f_text "Input NAMESPACE from list for get deployments or input ALL for get all deploys in all namespaces:"
   read NAMESPACE
   case $NAMESPACE in
       ALL | all | All) kubectl get deploy --all-namespaces;;
       "") f_warning_text "Cannot be empty";;
       *) kubectl get deploy --namespace $NAMESPACE 2> k8smt2;\
       grep -q -c "No resources found in" k8smt2;if [ $? -eq 1 ];\
       then f_text "Input deploy from list:";read DEP;rm k8smt2;break;else \
       echo "No resources found in $NAMESPACE";rm k8smt2;continue;fi;;
   esac
done
f_get_deploy_status
while true; do
        read -p "Do you want to edit $DEP? (y/n)" yn
        case $yn in
            [Yy]* )
            f_text "$EDITOR kubectl edit deployment/$DEP --namespace $NAMESPACE"
            KUBE_EDITOR=$EDITOR kubectl edit deployment/$DEP --namespace $NAMESPACE
            f_get_deploy_status
            break;;
            [Nn]* )
            echo "$DEP not changed"
            break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

f_menu_choice(){
    while true; do
    f_text_bl "     _                               
 /_ /_/  _   _ _  . _  .  _/_ _  _  /
/\ /_/ _\   / / // / //   /  /_//_// 
                                     "
    f_sep
    echo "1 - Setup New k8s Access"
    echo "2 - Delete Context"
    echo "3 - Switch Context"
    echo "4 - Get Pod and Run Command"
    echo "5 - Edit Deploy File"
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
            "5")
            f_menu_edit_deploy;;
            "777")
            f_text_bl "v1.4";;
            * ) echo "Please enter valid number or hit CTRL+C for exit.";;
        esac
    done
}

f_menu_choice


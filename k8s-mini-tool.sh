#!/bin/bash

ALLOW_FILE_LOAD=1
USE_COMMAND2=0
CERT=ca-auto.pem
EDITOR=nano
CONTAINER=app
COMMAND="(bash || ash || sh)"
COMMAND2=""
CONFIGFILE="k8s-mini-tool.set"

f_sep(){
echo "---------------------------"
}

f_text(){
case $2 in
    "bl")echo -e "\033[1;36m$1\033[0m";;
    "red")echo -e "\033[31mWARNING: $1\033[0m";sleep 1s;;
    *)echo -e "\033[32m$1\033[0m";;
esac
}

f_configfile(){
case $1 in
    "clear")
    echo -n > $CONFIGFILE;;
    "save")
    echo -n > $CONFIGFILE
    echo "export NAMESPACE=$NAMESPACE" >> $CONFIGFILE
    echo "export POD=$POD" >> $CONFIGFILE
    echo "export CONTAINER=$CONTAINER" >> $CONFIGFILE;;
esac
}

f_get_contexts(){
f_text "Get all contexts:"
kubectl config get-contexts
f_sep
}

f_check_namespace(){
if [[ $NAMESPACE =~ "prod" ]]
then
    f_text "Seems like its production... :O" "red"
fi
}

f_run_command(){
f_text "Run command $COMMAND2 $COMMAND in $NAMESPACE $POD $CONTAINER"
if [ "$USE_COMMAND2" = 1 ] && [ "$COMMAND2" != "" ]
then
    f_configfile "save"
    kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND2;$COMMAND"
else
    f_configfile "save"
    kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND"
fi
}

f_get_deploy_status(){
f_text "Current status $DEP $NAMESPACE:"
kubectl get deploy $DEP --namespace $NAMESPACE
}

f_menu_setup_access(){
f_text "Setup new k8s access" "bl";f_sep
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
        f_text "File $CERT Already exist! Create new one? (y/n)" "red"; read yn
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
            f_text "New certificate not set, use existing certificate $CERT" "red"
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
f_text "Switch k8s Context" "bl";f_sep
f_get_contexts
f_text "Input NAME context to switch to:";read CONTEXTNAME
kubectl config use-context $CONTEXTNAME
f_get_contexts
f_configfile "clear"
}

f_menu_delete_context(){
f_text "Delete k8s Context" "bl";f_sep
f_get_contexts
f_text "Input NAME context to be deleted:";read CONTEXTNAME
kubectl config unset contexts.$CONTEXTNAME
f_get_contexts
f_configfile "clear"
}

f_menu_get_pod(){
f_text "Get New Pod and Run Command" "bl";f_sep
f_get_contexts
kubectl get ns
while true; do
   f_text "Input NAMESPACE from list for get pods or input ALL for get all pods in all namespaces:"
   read NAMESPACE
   f_check_namespace
   case $NAMESPACE in
       ALL | all | All) kubectl get pods --all-namespaces;;
       "") f_text "Cannot be empty" "red";;
       *) kubectl get pods --namespace $NAMESPACE 2> k8smt;\
       grep -q -c "No resources found in" k8smt;if [ $? -eq 1 ];\
       then f_text "Input PODNAME from list:";read POD;rm k8smt;break;else \
       echo "No resources found in $NAMESPACE";rm k8smt;continue;fi;;
   esac
done

f_run_command
}

f_menu_get_selected_pod(){
f_text "Get Selected Pod and Run Command" "bl";f_sep
if [ $(stat -c "%s" $CONFIGFILE) -eq 0 ]
then
    f_text "No Pod Selected. Select one firstly." "red"
else
f_run_command
fi
}

f_menu_get_files_from_pod() {
while true; do
    f_text "Get Files from Pod" "bl";f_sep
    f_text "Input full path to file IN POD:";read FILEFROMPOD
    f_text "Input full path to LOCAL file, which will be save FROM POD:";read FILELOCAL
    f_text "EXEC:kubectl cp $NAMESPACE/$POD:$FILEFROMPOD $FILELOCAL -c $CONTAINER"
    read -p "Do you want to recieve file from pod using current settings? (y/n)" yn
    case $yn in
        [Yy]* )
        kubectl cp $NAMESPACE/$POD:$FILEFROMPOD $FILELOCAL -c $CONTAINER
        if [ -e $FILELOCAL ]
        then
            f_text "Check File: File recived succesfully"
            ls -l $FILELOCAL
        else
            f_text "File doesnt recieve" "red"
        fi
        ;;
        [Nn]* )
        f_text "Input full path to file IN POD:";read FILEFROMPOD
        f_text "Input full path to LOCAL file, which will be save FROM POD:";read FILELOCAL
        f_text "Input NAMESPACE:";read NAMESPACE
        f_text "Input POD:";read POD
        f_text "Input CONTAINER:";read CONTAINER
        f_text "EXEC:kubectl cp $NAMESPACE/$POD:$FILEFROMPOD $FILELOCAL -c $CONTAINER"
        kubectl cp $NAMESPACE/$POD:$FILEFROMPOD $FILELOCAL -c $CONTAINER
        if [ -e $FILELOCAL ]
        then
            f_text "Check File: File recived succesfully"
            ls -l $FILELOCAL
        else
            f_text "File doesnt recieve" "red"
        fi
        ;;
        * ) echo "Please answer y (yes) or n (no).";;
   esac
done
}

f_menu_send_files_to_pod() {
f_text "Sending Files to Pod" "bl";f_sep
if [ $ALLOW_FILE_LOAD = 1 ]
then
    while true; do
        f_text "Input full path to LOCAL file, which will be send in pod(50kB max):";read FILELOCAL
        if [ $FILELOCAL ] && [ -e $FILELOCAL ]
        then
            FILESIZE=$(wc -c $FILELOCAL | awk '{print $1}')
            if [ $FILESIZE -lt 51200 ]
            then
                f_text "Input full path to send file IN POD:";read FILETOPOD
                f_text "EXEC:kubectl cp $FILELOCAL $NAMESPACE/$POD:$FILETOPOD -c $CONTAINER"
                read -p "Do you want to SEND file in pod using current settings? (y/n)" yn
                case $yn in
                    [Yy]* )
                    kubectl cp $FILELOCAL $NAMESPACE/$POD:$FILETOPOD -c $CONTAINER
                    f_text "Check file:";kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "ls -l $FILETOPOD;exit"
                    ;;
                    [Nn]* )
                    f_text "Input full path to LOCAL file, which will be send in pod(50kB max):";read FILELOCAL
                    f_text "Input full path to send file IN POD:";read FILETOPOD
                    f_text "Input NAMESPACE:";read NAMESPACE
                    f_text "Input POD:";read POD
                    f_text "Input CONTAINER:";read CONTAINER
                    f_text "EXEC:kubectl cp $FILELOCAL $NAMESPACE/$POD:$FILETOPOD -c $CONTAINER"
                    read -p "Do you want to SEND file in pod using current settings? (y/n)" yn
                    case $yn in
                        [Yy]* )
                        kubectl cp $FILELOCAL $NAMESPACE/$POD:$FILETOPOD -c $CONTAINER
                        f_text "Check file:";kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "ls -l $FILETOPOD;exit"
                        ;;
                        [Nn]* )
                        f_text "Aborted" "red"
                        ;;
                        * ) echo "Please answer y (yes) or n (no).";;
                    esac
                esac
            fi
        else
        f_text "No file to send or max limit(50kb) reached." "red"
        fi
    done
else
    f_text "Sending files is disabled." "red"
fi
}

f_menu_edit_deploy(){
f_text "Edit Deploy File" "bl";f_sep
f_get_contexts
kubectl get ns
while true; do
   f_text "Input NAMESPACE from list for get deployments or input ALL for get all deploys in all namespaces:"
   read NAMESPACE
   f_check_namespace
   case $NAMESPACE in
       ALL | all | All) kubectl get deploy --all-namespaces;;
       "") f_text "Cannot be empty" "red";;
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
            f_text "EXEC:$EDITOR kubectl edit deployment/$DEP --namespace $NAMESPACE"
            KUBE_EDITOR=$EDITOR kubectl edit deployment/$DEP --namespace $NAMESPACE
            f_get_deploy_status
            break;;
            [Nn]* )
            f_text "$DEP not changed" "red"
            break;;
            * ) echo "Please answer y (yes) or n (no)";;
        esac
    done
}

f_menu_choice(){
while true; do
    f_text "     _
 /_ /_/  _   _ _  . _  .  _/_ _  _  /
/\ /_/ _\   / / // / //   /  /_//_// 
                                     " "bl"
    f_sep
    f_text "Selected Context:" "bl"
    kubectl config current-context
    if [ $(stat -c "%s" $CONFIGFILE) -eq 0 ]
    then
        f_text "No current Objects Selected" "bl"
    else
        f_text "Selected Objects:" "bl"
        source $CONFIGFILE
        echo "NAMESPACE=$NAMESPACE"
        echo "POD=$POD"
        echo "CONTAINER=$CONTAINER"
    fi
    f_sep
    echo "1 - Setup New k8s Access"
    echo "2 - Delete Context"
    echo "3 - Switch Context"
    echo "4 - Get New Pod and Run Command"
    echo "5 - Get Selected Pod and Run Command"
    echo "6 - Edit Deploy File"
    echo "7 - Get Files from Pod"
    echo "8 - Send Files to Pod"
    f_sep
    echo "Enter your choice:";read choice;f_sep
    case $choice in
        "1") f_menu_setup_access;;
        "2") f_menu_delete_context;;
        "3") f_menu_switch_context;;
        "4") f_menu_get_pod;;
        "5") f_menu_get_selected_pod;;
        "6") f_menu_edit_deploy;;
        "7") f_menu_get_files_from_pod;;
        "8") f_menu_send_files_to_pod;;
        "exit") f_text "Bye!" "bl";exit;;
        "777") f_text "v1.6" "bl";sleep 3s;;
        * ) echo "Please enter valid number or input "exit" for exit.";sleep 1s;;
    esac
done
}

f_menu_choice


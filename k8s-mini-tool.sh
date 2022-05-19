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
echo -e "\033[32m$1\033[0m"
}

f_text_bl(){
echo -e "\033[1;36m$1\033[0m"
}

f_warning_text(){
echo -e "\033[31mWARNING:$1\033[0m"
}

f_get_contexts(){
f_text "Get all contexts:"
kubectl config get-contexts
f_sep
}

f_run_command(){
f_text "Run command $COMMAND2 $COMMAND in $NAMESPACE $POD $CONTAINER"
if [ "$USE_COMMAND2" = 1 ] && [ "$COMMAND2" != "" ]
then
    echo -n > $CONFIGFILE
    echo "export NAMESPACE=$NAMESPACE" >> $CONFIGFILE
    echo "export POD=$POD" >> $CONFIGFILE
    echo "export CONTAINER=$CONTAINER" >> $CONFIGFILE
    kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND2;$COMMAND"
else
    kubectl exec -i -t -n $NAMESPACE $POD -c $CONTAINER "--" sh -c "$COMMAND"
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
f_text_bl "Switch k8s Context";f_sep
f_get_contexts
f_text "Input NAME context to switch to:";read CONTEXTNAME
kubectl config use-context $CONTEXTNAME
f_get_contexts
echo -n > $CONFIGFILE
}

f_menu_delete_context(){
f_text_bl "Delete k8s Context";f_sep
f_get_contexts
f_text "Input NAME context to be deleted:";read CONTEXTNAME
kubectl config unset contexts.$CONTEXTNAME
f_get_contexts
echo -n > $CONFIGFILE
}

f_menu_get_pod(){
f_text_bl "Get New Pod and Run Command";f_sep
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

f_menu_get_selected_pod(){
f_text_bl "Get Selected Pod and Run Command";f_sep
if [ $(stat -c "%s" $CONFIGFILE) -eq 0 ]
then
    f_warning_text "No Pod Selected. Select one firstly"
else
f_run_command
fi
}

f_menu_get_files_from_pod() {
while true; do
    f_text_bl "Get Files from Pod";f_sep
    f_text "Input full path to file IN POD:";read FILEFROMPOD
    f_text "Input full path to LOCAL file, which will be save FROM POD:";read FILELOCAL
    f_text "EXEC:kubectl cp $NAMESPACE/$POD:$FILEFROMPOD $FILELOCAL -c $CONTAINER"
    read -p "Do you want to recieve file from pod using current settings? (y/n)" yn
    case $yn in
        [Yy]* )
        kubectl cp $NAMESPACE/$POD:$FILEFROMPOD $FILELOCAL -c $CONTAINER
        if [ $FILELOCAL ]
        then
            f_text "Check File: File recived succesfully"
        else
            f_warning_text "File doesnt recieve"
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
        if [ $FILELOCAL ]
        then
            f_text "Check File: File recived succesfully"
        else
            f_warning_text "File doesnt recieve"
        fi
        ;;
        * ) echo "Please answer y (yes) or n (no).";;
   esac
done
}

f_menu_send_files_to_pod() {
f_text_bl "Sending Files to Pod";f_sep
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
                        f_warning_text "Aborted"
                        ;;
                        * ) echo "Please answer y (yes) or n (no).";;
                    esac
                esac
            fi
        else
        f_warning_text "No file to send or max limit(50kb) reached"
        fi
    done
else
    f_warning_text "Sending files is disabled"
fi
}

f_menu_edit_deploy(){
f_text_bl "Edit Deploy File";f_sep
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
            f_text "EXEC:$EDITOR kubectl edit deployment/$DEP --namespace $NAMESPACE"
            KUBE_EDITOR=$EDITOR kubectl edit deployment/$DEP --namespace $NAMESPACE
            f_get_deploy_status
            break;;
            [Nn]* )
            echo "$DEP not changed"
            break;;
            * ) echo "Please answer y (yes) or n (no)";;
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
    f_text_bl "Selected Context:"
    kubectl config current-context
    if [ $(stat -c "%s" $CONFIGFILE) -eq 0 ]
    then
        f_text_bl "No current Objects Selected"
    else
        f_text_bl "Selected Objects:"
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
            "1")
            f_menu_setup_access;;
            "2")
            f_menu_delete_context;;
            "3")
            f_menu_switch_context;;
            "4")
            f_menu_get_pod;;
            "5")
            f_menu_get_selected_pod;;
            "6")
            f_menu_edit_deploy;;
            "7")
            f_menu_get_files_from_pod;;
            "8")
            f_menu_send_files_to_pod;;
            "exit")
            exit;;
            "777")
            f_text_bl "v1.5";;
            * ) echo "Please enter valid number or input "exit" for exit.";;
        esac
    done
}

f_menu_choice


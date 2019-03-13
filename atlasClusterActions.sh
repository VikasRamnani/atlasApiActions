#!/bin/bash


#########################
# The command line help #
#########################
display_help() {
    echo "Usage: $0 --option=<VALUE> " >&2
    echo "Possible options:" >&2
    echo "   --username               : USERNAME or public key of a user having project owner rights"
    echo "   --api_key                : API key corresponding to the username or public key "
    echo "   --source-project-id      : Source Project id on which you want to perform the action"
    echo "   --source-cluster-name    : Source Cluster id"
    echo "   --target-project-id      : Target project id for copy action"
    echo "   --action                 : Action < pause/resume/get-alertconfig/copy-alertconfigs/get-whitelist/copy-whitelist/get-databaseusers/copy-databaseusers/get-customroles/copy-customroles >"

    # echo some stuff here for the -a or --add-options 
    exit 1
}

#######################
# check valid actions #
#######################

start_action(){
case $ACTION in
  pause)
    pause_cluster
      ;;
  resume)
    resume_cluster
      ;;
  get-alertconfigs)
    get_alertconfigs
      ;;
  copy-alertconfigs)
    copy_alertconfigs
      ;;
  get-whitelist)
    get_whitelist
      ;;
  copy-whitelist)
    copy_whitelist
      ;;
  get-databaseusers)
    get_databaseusers
      ;;
  copy-databaseusers)
    copy_databaseusers
      ;;
  get-customroles)
    get_customroles
      ;;
  copy-customroles)
    copy_customroles
      ;;
   *)

    echo "Action not authorised"
    display_help
      ;;
esac
}


#####################
# Pause the cluster #
#####################

pause_cluster(){
curl -s -u "$USERNAME:$API_KEY" --digest -H "Content-Type: application/json" -X PATCH "https://cloud.mongodb.com/api/atlas/v1.0/groups/$SOURCE_PROJECT_ID/clusters/$SOURCE_CLUSTER_NAME" --data '
{
  "paused" : true
}'

}
##################
# Resume Cluster #
##################

resume_cluster(){
curl -s -u "$USERNAME:$API_KEY" --digest -H "Content-Type: application/json" -X PATCH "https://cloud.mongodb.com/api/atlas/v1.0/groups/$SOURCE_PROJECT_ID/clusters/$SOURCE_CLUSTER_NAME" --data '
{
  "paused" : false
}'
}

###########################
# Get Alert Configuration #
###########################
get_alertconfigs(){
curl -s GET -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$SOURCE_PROJECT_ID/alertConfigs" 2>/dev/null
}

############################
# Copy Alert Configuration #
############################
copy_alertconfigs(){

result=$(get_alertconfigs)
echo $result | jq -c '.results[]' | 
while read line;
do
  alert=`echo $line | jq 'del('.created','.id','.links','.matchers','.updated','.groupId')'`;

  curl -s -X POST -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$TARGET_PROJECT_ID/alertConfigs" \
    -H "Content-Type: application/json"\
    --data "${alert}"
done;
}

#################
# Get Whitelist #
#################
get_whitelist(){
curl -s GET -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$SOURCE_PROJECT_ID/whitelist" 2>/dev/null
}

##################
# Copy Whitelist #
##################
copy_whitelist(){

result=$(get_whitelist)
whitelist=`echo $result | jq -c '.results' | jq 'del('.[].links','.[].groupId','.[].cidrBlock')'`;

  curl -s -X POST -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$TARGET_PROJECT_ID/whitelist" \
    -H "Content-Type: application/json"\
    --data "${whitelist}"
}

#############
# Get Users #
#############
get_databaseusers(){
curl -s GET -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$SOURCE_PROJECT_ID/databaseUsers" 2>/dev/null
}

#######################
# Copy Database users #
#######################
copy_databaseusers(){
users=$(get_databaseusers)
for user in $(echo "${users}" | jq -c '.results[]'); do
  username=`echo $user | jq -r '.username'`;
  password=$(get-password-for-user $username);
  userwithpass=`echo $user | jq 'del('.links')' |  jq --arg pass "$password" '. + {password:$pass}'`;
  curl -s -X POST -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$TARGET_PROJECT_ID/databaseUsers" \
    -H "Content-Type: application/json"\
    --data "${userwithpass}"
done
}

###########################
# Method to get Password ##
###########################
# NOTE : This function should be changed in case password is assigned in different manner ( for example property file)
get-password-for-user(){
  read -sp "password for user $1 : " password
  echo "$password";
}

##############################
# GET Database Custom roles #
##############################
get_customroles(){
  curl -s GET -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$SOURCE_PROJECT_ID/customDBRoles/roles" 2>/dev/null
}

##############################
# Copy Database Custom roles #
##############################
copy_customroles(){
roles=$(get_customroles)
for role in $(echo "${roles}" | jq -c '.[]'); do
  curl -s -X POST -u "$USERNAME:$API_KEY" --digest "https://cloud.mongodb.com/api/atlas/v1.0/groups/$TARGET_PROJECT_ID/customDBRoles/roles" \
    -H "Content-Type: application/json"\
    --data "${role}"
done
}


########
# MAIN #
########


while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            display_help
            exit
            ;;
        --username)
            USERNAME=$VALUE
            ;;
        --api-key)
            API_KEY=$VALUE
            ;;
        --source-project-id)
            SOURCE_PROJECT_ID=$VALUE
            ;;
        --source-cluster-name)
            SOURCE_CLUSTER_NAME=$VALUE
            ;;
        --target-project-id)
            TARGET_PROJECT_ID=$VALUE
            ;;
        --action)
            ACTION=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

start_action

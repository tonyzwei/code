#!/bin/bash

## All Go pipelines within the Release_Manager group are executed by Go agents which have resources of "release".
## 
## Defined in pipeine Environment Variables
##
##   APP_TEMPLATE_DEPLOY_TEST
##   APP_TEMPLATE_TEST
##

release_setting()
{
   PL_WORKSPACE=$(pwd)/../..
   REL_PLAN=$(pwd)/releases.json
   REL_PLAN_TMP=$PL_WORKSPACE/releases_tmp.json
   REL_PLAN_REV=$PL_WORKSPACE/releases_rev.json
   LOG_RELEASE=$PL_WORKSPACE/release_details
   LOG_DIR=$PL_WORKSPACE/work_logs
   APP_SRC=/var/go/Releases/src
   GO_DETAILS=/var/go/Releases/details

   ## THIS MEANS ALL RELEASE PREPARATION AND TRIGGER WILL BE DONE IN A GO AGENT NODE

   [ ! -d $LOG_DIR ] && mkdir $LOG_DIR
   [ ! -d $LOG_RELEASE ] && mkdir $LOG_RELEASE
   [ ! -d /var/go/Releases ] && mkdir /var/go/Releases
   [ ! -d $APP_SRC ] && mkdir $APP_SRC
   [ ! -d $GO_DETAILS ] && mkdir $GO_DETAILS

   if [ -s $REL_PLAN ] ; then
      cp $REL_PLAN $REL_PLAN_TMP

   ## Obtain env_stage value and uppercase the first letter and lowercase the rest

      ENV_STG=$(jq -r '.env_stage' $REL_PLAN)
      ENV_STG=$(echo $ENV_STG | tr '[:upper:]' '[:lower:]')
      ENV_STG=$(tr '[:lower:]' '[:upper:]' <<< ${ENV_STG:0:1})${ENV_STG:1}
      
      PROJ_NUMBER=$(jq '.release | length' $REL_PLAN)
   fi
}

pipeline_materials_cleanup()
{
   ## $3 is either dependency or git

   cat $1 | jq "del(.materials[] | select(.type == \"$3\"))" > $2

   if cat $2 | jq ".materials[] | select(.type == \"$3\")" | grep "\"type\": \"$3\"," > /dev/null
   then
      echo -e "... Failed to clean up pipeline dependencies."
      EXIT_CODE=1
   else
      echo -e "... Succeeded to clean up pipeline materials $3."
   fi
}

pipeline_dependency_update()
{
   cat $1 | jq ".materials += [{\"type\": \"dependency\", \"attributes\": {\"pipeline\": \"$3\", \"stage\": \"$4\", \"name\": \"$3\", \"auto_update\": true }}]" > $2
   jq -r '.materials[] | select(.type == "dependency") | .attributes.pipeline' $2 | grep $3 > /dev/null 2>&1
   if [ "$?" -eq "0" ] ; then
      echo -e "... Succeeded to add a pipeline $3 as part of dependencies."
   else
      echo -e "... Failed to add a pipeline $3 as part of dependencies."
      EXIT_CODE=1
   fi
}

pipeline_env_update()
{
   cat $1 | jq "(.environment_variables[] | select(.name == \"$3\") | .value) |= \"$4\"" > $2
   if [ "$(jq -r ".environment_variables[] | select(.name == \"$3\") | .value" $2)" = "$4" ] ; then
      echo -e "... Succeeded to update $3 to $4."
   else
      echo -e "... Failed to update $3 to $4."
      EXIT_CODE=1
   fi
}

pipeline_template_switch()
{
   cat $1 | jq ".template = \"$2\"" > $3
   if [ "$(jq -r '.template' $3)" = "$2" ] ; then
      echo -e "... Succeeded to switch pipeline templete to $2."
   else
      echo -e "... Failed to switch pipeline templete to $2."
      EXIT_CODE=1
      fi
}

app_reader()
{
   PROJ_NAME=$(jq -r ".release[$i].project" $REL_PLAN)
   REL_TAG=$(jq -r ".release[$i].release_tag" $REL_PLAN)
   DEPENDS=$(jq -r ".release[$i].dependency" $REL_PLAN)
   DEPENDS_NR=$(jq -r ".release[$i].dependency" $REL_PLAN | wc -w)

   PIPELINE_ID_FILE=$LOG_DIR/pipeline_id.json
   MISSING_APPS=$LOG_DIR/missing_apps_${PROJ_NAME}.log

   if echo $ENV_STG | grep -i "demo" > /dev/null 2>&1 ; then
      PIPELINE_NAME=${PROJ_NAME}
      STG_ENDPOINT=""
   else
      PIPELINE_NAME=${PROJ_NAME}_$ENV_STG
      STG_ENDPOINT=/$ENV_STG
   fi
   curl -s -S "$GOCD_URL/go/api/admin/pipelines/$PIPELINE_NAME" \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" \
        -H 'Accept: application/vnd.go.cd.v5+json' \
        -o $PIPELINE_ID_FILE

   GO_PL_NAME=$(jq -r '.name' $PIPELINE_ID_FILE)
   APP_REPO_URL=$(jq -r '.materials[0].attributes.url' $PIPELINE_ID_FILE)

   if echo $PIPELINE_NAME | grep -i "$GO_PL_NAME" > /dev/null 2>&1 ; then
      echo -e "The pipeline $GO_PL_NAME is verified.\n"
   else
      echo -e "The pipeline $GO_PL_NAME failed to be verified.\n"
      EXIT_CODE=0
   fi

   sed -i "/\"dependency\": /s/$PROJ_NAME/$GO_PL_NAME/Ig" $REL_PLAN_TMP

   cat $REL_PLAN_TMP | jq ".release[$i].gopipeline = \"$GO_PL_NAME\"" > $REL_PLAN_REV
   cp $REL_PLAN_REV $REL_PLAN_TMP

   DEPENDED_APPS=`echo $DEPENDS | tr ',' ' '`

   for app in $DEPENDED_APPS
   do
      jq -r '.release[].project' $REL_PLAN | grep -i $app > /dev/null
      if [ "$?" -ne "0" ] ; then
         echo "$app" >> $MISSING_APPS
         EXIT_CODE=1
      fi
   done
   if [ -s $MISSING_APPS ] ; then
      echo -e "The following dependeny app(s) are missing in the project list"
      cat $MISSING_APPS; echo ""
      EXIT_CODE=1
   fi
}

app_printout()
{
   echo -e ""
   echo -e "project name  = $PROJ_NAME"
   echo -e "release_tag   = $REL_TAG"
   echo -e "dependency    = $DEPENDS (Totally $DEPENDS_NR apps$([ -s $MISSING_APPS ] && echo ", Some missing"))"
   echo -e "pipeline name = $GO_PL_NAME"
}


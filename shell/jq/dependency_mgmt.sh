#!/bin/bash

## Defined in pipeine Environment Variables
##
## APP_TEMPLATE_DEPLOY_TEST
## APP_TEMPLATE_TEST
##

source bin/goapi_calls.sh
source bin/release_env.sh

release_setting

cp bin/* $LOG_RELEASE
cp $REL_PLAN_REV $LOG_RELEASE

PIPELINE_LST=$LOG_RELEASE/pipeline_list.txt

EXIT_CODE=0

for i in $(seq 0 $((PROJ_NUMBER-1)))
do
   echo -e "\nWork on No. $((i+1)) Porject ------------------------------------------------------------------\n"

   GO_PL_NAME=$(jq -r ".release[$i].gopipeline" $REL_PLAN_REV)
   echo $GO_PL_NAME >> $PIPELINE_LST

   GO_PL_CONFIG=$LOG_DIR/pipeline_config_${GO_PL_NAME}.json
   GO_PL_CONFIG_ORIG=$LOG_RELEASE/pipeline_config_orig_${GO_PL_NAME}.json
   GO_PL_CONFIG_NEW=$LOG_RELEASE/pipeline_config_new_${GO_PL_NAME}.json
   PIPELINE_TMP1=$LOG_DIR/pipeline_config_tmp1.json
   PIPELINE_TMP2=$LOG_DIR/pipeline_config_tmp2.json

   pipeline_pause $GO_PL_NAME
   pipeline_conf $GO_PL_NAME $GO_PL_CONFIG

   ## MANIPULATE GO PIPELINE CONFIGURATION JSON FILE

   echo -e "\nUpdate pipeline configurations:"

   jq 'del(._links)' $GO_PL_CONFIG > $PIPELINE_TMP1
   jq 'del(.origin)' $PIPELINE_TMP1 > $PIPELINE_TMP2

   cp $PIPELINE_TMP2 $GO_PL_CONFIG_ORIG

   pipeline_materials_cleanup $PIPELINE_TMP2 $PIPELINE_TMP1 dependency

   ## NO MATERIALS GET INVOLVED WITH APP PIPELINES BECAUSE IT IS ALL ABOUT API CALLS TO MEDISTRANO
   cp $PIPELINE_TMP1 $PIPELINE_TMP2
   pipeline_materials_cleanup $PIPELINE_TMP2 $PIPELINE_TMP1 git

   GO_PL_DEPENDS=$(jq -r ".release[$i].dependency" $REL_PLAN_REV |  tr ',' ' ')
   echo -e "\n$GO_PL_NAME depends on: $GO_PL_DEPENDS"

   if [ "$(echo $GO_PL_DEPENDS | wc -w)" -gt "0" ] ; then
      for app in $GO_PL_DEPENDS
      do
         pipeline_dependency_update $PIPELINE_TMP1 $PIPELINE_TMP2 $app Test
         cp $PIPELINE_TMP2 $PIPELINE_TMP1
      done
   else
      pipeline_dependency_update $PIPELINE_TMP1 $PIPELINE_TMP2 Release_Trigger Trigger
   fi

   REL_TAG=$(jq -r ".release[$i].release_tag" $REL_PLAN_REV)
   echo -e "\n$GO_PL_NAME runs with release tag $REL_TAG"

   if [ "$(echo $REL_TAG | wc -w)" -eq "0" ] ; then
      pipeline_template_switch $PIPELINE_TMP2 $APP_TEMPLATE_TEST $GO_PL_CONFIG_NEW
   else
      pipeline_env_update $PIPELINE_TMP2 $GO_PL_CONFIG_NEW GITREF_OVERRIDE $REL_TAG
      cp $GO_PL_CONFIG_NEW $PIPELINE_TMP2
      pipeline_template_switch $PIPELINE_TMP2 $APP_TEMPLATE_DEPLOY_TEST $GO_PL_CONFIG_NEW
   fi
done

ENV_STG=$(jq -r '.env_stage' $REL_PLAN_REV)

echo -e "\n## All pipeline config json files are archived:"
echo -e "$GO_DETAILS/$ENV_STG."
rm -rf $GO_DETAILS/$ENV_STG
cp -r $LOG_RELEASE $GO_DETAILS/$ENV_STG

echo -e "\n\n"; sleep 1
exit $EXIT_CODE

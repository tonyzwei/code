#!/bin/bash
# This script is used in Go pipeline directly

release_pipeline_setting()
{
   source goapi_calls.sh
   source release_env.sh

   REL_PLAN_REV=releases_rev.json
   PIPELINE_LST=pipeline_list.txt

   PL_DIR=log_${PL_NAME}
   [ ! -d $PL_DIR ] && mkdir $PL_DIR

   PL_CONF_RAW=$PL_DIR/pl_config_raw.json
   PL_CONF_TMP1=$PL_DIR/pl_config_tmp1.json
   PL_CONF_TMP2=$PL_DIR/pl_config_tmp2.json
   PL_CONF_ORIG=$PL_DIR/pl_config_orig.json
   PL_CONF_WORK=$PL_DIR/pl_config_work.json
   PL_DEPENDS_LST=$PL_DIR/pl_depends.lst
}

pipeline_update_setting()
{
   pipeline_pause $PL_NAME
   pipeline_conf $PL_NAME $PL_CONF_RAW

   jq 'del(._links)' $PL_CONF_RAW  > $PL_CONF_TMP1
   jq 'del(.origin)' $PL_CONF_TMP1 > $PL_CONF_TMP2
   
   pipeline_materials_cleanup $PL_CONF_TMP2 $PL_CONF_TMP1 dependency
   pipeline_env_update $PL_CONF_TMP1 $PL_CONF_TMP2 MEDISTRANO_STAGE ""
   cp $PL_CONF_TMP2 $PL_CONF_ORIG
}

update_app_pipeline_reset()
{
   ## This is important to let pipeline App_PIpeline_Rest know where to find pipeline sources
   PL_NAME=$1
   pipeline_update_setting
   echo -e "\nTHIS IS PIPELINE CONFIG UPDATE OF RELEASE TRIGGER\n"
   if [ "$2" = "reset" ] ; then
      cp $PL_CONF_ORIG $PL_CONF_WORK
   else
      pipeline_env_update $PL_CONF_ORIG $PL_CONF_WORK MEDISTRANO_STAGE $ENV_STG
   fi
   pipeline_update $PL_NAME $PL_CONF_WORK
}

update_release_complete()
{
   PL_NAME=$1
   pipeline_update_setting
   echo -e "\nTHIS IS PIPELINE CONFIG UPDATE OF RELEASE COMPLETE\n"

   if [ "$2" = "reset" ] ; then
      cp $PL_CONF_ORIG $PL_CONF_WORK
   else
      ## If an app has no dependent, then it is upstream pipeline of Release_Complete
      cp $PL_CONF_ORIG $PL_CONF_TMP1
      cat $REL_PLAN_REV | jq -r '.release[].dependency' > $PL_DEPENDS_LST
      cat $PIPELINE_LST | while read PROJ_NAME
      do
         grep $PROJ_NAME $PL_DEPENDS_LST > /dev/null 2>&1
         if [ "$?" -ne "0" ] ; then
            pipeline_dependency_update $PL_CONF_TMP1 $PL_CONF_TMP2 $PROJ_NAME Test
            cp $PL_CONF_TMP2 $PL_CONF_TMP1
         fi
      done
      cp $PL_CONF_TMP2 $PL_CONF_WORK
   fi
   pipeline_update $PL_NAME $PL_CONF_WORK
}

#!/bin/bash
##
## Purpose: 
##   1. Verify the releases.json
##   2. Come out releases_rev.json which has standard and enriched json file for dependency management.
##
## Defined in pipeine Environment Variables
##   APP_TEMPLATE_DEPLOY_TEST
##   APP_TEMPLATE_TEST
##

source bin/goapi_calls.sh
source bin/release_env.sh

release_setting

echo -e "\n$REL_PLAN\n"
cat $REL_PLAN

EXIT_CODE=0

for i in $(seq 0 $((PROJ_NUMBER-1)))
do
   echo -e "\nPROJECT WORK SHEET --------------------------------------------------------------------\n"

   app_reader

   ## PROJECTS AND STAGES CHECKUP WITH MEDISTRANO

   STRANO_LOG=$LOG_DIR/medistrano_api_${GO_PL_NAME}.log

   echo -e "API endpoint: ${STRANO_API}/projects/${PROJ_NAME}/stages${STG_ENDPOINT}"

   curl -s -S --get \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $MEDISTRANO_TOKEN" \
        -o $STRANO_LOG \
        ${STRANO_API}/projects/${PROJ_NAME}/stages${STG_ENDPOINT}

   if grep "could not be found" $STRANO_LOG > /dev/null 2>&1 ; then
      cat $STRANO_LOG | python -mjson.tool
      EXIT_CODE=1
   else
      echo -e "Project and Stage are verified in Medistrano."
   fi

   ## GIT REPO AND RELEASE TAG CHECKUP

   if echo $APP_REPO_URL | grep "\.git" > /dev/null 2>&1 ; then
       APP_REPO_URL=${APP_REPO_URL::-4}
   fi
   APP_REPO_NAME=`echo $APP_REPO_URL | tr '/' ' ' | awk '{print $4}'`

   echo -e "\nGit repo: $APP_REPO_NAME"
   if [ -d $APP_SRC/$APP_REPO_NAME ] ; then
      cd $APP_SRC/$APP_REPO_NAME
      git pull
   else
      cd $APP_SRC
      git clone $APP_REPO_URL
      cd $APP_REPO_NAME
   fi
   if [ -n "$REL_TAG" ] ; then
      echo -e "\nVerify release tag:"
      git show-ref $REL_TAG
      if [ "$?" -ne "0" ] ; then
         echo "The release tag $REL_TAG is not valid."
         EXIT_CODE=1
      fi
   fi
   cd $LOG_DIR/..

   app_printout
   echo -e "git repo url  = $APP_REPO_URL\n"
   cat $REL_PLAN_TMP | jq ".release[$i].git_repo_url = \"$APP_REPO_URL\"" > $REL_PLAN_REV
   cp $REL_PLAN_REV $REL_PLAN_TMP
done

cat $REL_PLAN_TMP | jq ".env_stage = \"$ENV_STG\"" > $REL_PLAN_REV

[ ! -d $GO_DETAILS/$ENV_STG ] && mkdir $GO_DETAILS/$ENV_STG
cp $REL_PLAN_REV $GO_DETAILS/$ENV_STG

exit $EXIT_CODE

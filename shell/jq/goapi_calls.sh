#!/bin/bash

LOG_DIR=$(pwd)/logs
[ ! -d $LOG_DIR ] && mkdir $LOG_DIR

pipeline_update()
{
   GO_PL_NAME=$1
   GO_PL_CONF_FILE=$2
   VB_LOG=$LOG_DIR/${1}_verbose.log

   curl -s -S "$GOCD_URL/go/api/admin/pipelines/$GO_PL_NAME" \
        -H 'Accept: application/vnd.go.cd.v5+json' \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" -i | grep "ETag" > $VB_LOG

   ETAG=$(grep "ETag: " $VB_LOG | tr '"' ' ' | awk '{print $2}')

   echo -e "\n------------------------------------------------------------------\n"
   echo -e "GO_PL_NAME = $GO_PL_NAME"
   echo -e "GO_PL_CONF_FILE = $GO_PL_CONF_FILE"
   echo -e "ETag: $ETAG\n"

   curl -v -s -S "$GOCD_URL/go/api/admin/pipelines/$GO_PL_NAME" \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" \
        -H 'Accept: application/vnd.go.cd.v5+json' \
        -H 'Content-Type: application/json' \
        -H "If-Match: \"$ETAG\"" \
        -X PUT -d@${GO_PL_CONF_FILE} 2> $VB_LOG

   echo -e "\nUpdated Go pipeline $GO_PL_NAME."
   sleep 1
}

pipeline_pause()
{
   GO_PL_NAME=$1
   GO_PL_ACTION_LOG=$LOG_DIR/pipeline_pause_${GO_PL_NAME}.log

   echo -e "Pause the pipeline:"; sleep 1
   curl -s -S "$GOCD_URL/go/api/pipelines/$GO_PL_NAME/pause" \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" \
        -H 'Accept: application/vnd.go.cd.v1+json' \
        -H 'Content-Type: application/json' \
        -d '{"pause_cause": "reparation for release"}' \
        -X POST -o $GO_PL_ACTION_LOG

   grep -E ' paused successfully.|is already paused.' $GO_PL_ACTION_LOG > /dev/null 2>&1
   if [ "$?" -ne "0" ] ; then
      echo "... Failed to pause the pipeline $GO_PL_NAME."
      EXIT_CODE=1
   else
      echo "... Succeeded to pause the pipeline $GO_PL_NAME."
   fi
}

pipeline_unpause()
{
   GO_PL_NAME=$1
   GO_PL_ACTION_LOG=$LOG_DIR/pipeline_unpause_${GO_PL_NAME}.log

   echo -e "Unpause the pipeline:"; sleep 1
   curl -s -S "$GOCD_URL/go/api/pipelines/$GO_PL_NAME/unpause" \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" \
        -H 'Accept: application/vnd.go.cd.v1+json' \
        -H 'X-GoCD-Confirm: true' \
        -X POST -o $GO_PL_ACTION_LOG

   grep -E ' unpaused successfully.|is already unpaused.' $GO_PL_ACTION_LOG > /dev/null 2>&1
   if [ "$?" -ne "0" ] ; then
      echo "... Failed to unpause the pipeline $GO_PL_NAME."
      EXIT_CODE=1
   else
      echo "... Succeeded to unpause the pipeline $GO_PL_NAME."
   fi
}

pipeline_trigger()
{
   GO_PL_NAME=$1
   GO_PL_ACTION_LOG=$LOG_DIR/pipeline_schedule_${GO_PL_NAME}.log

   echo -e "\nTrigger the pipeline $GO_PL_NAME:"; sleep 1
   curl -s -S "$GOCD_URL/go/api/pipelines/$GO_PL_NAME/schedule" \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" \
        -H 'Accept: application/vnd.go.cd.v1+json' \
        -H 'X-GoCD-Confirm: true' \
        -X POST -o $GO_PL_ACTION_LOG

   grep "Request to schedule pipeline $GO_PL_NAME accepted." $GO_PL_ACTION_LOG > /dev/null 2>&1
   if [ "$?" -ne "0" ] ; then
      echo "... Failed to trigger the pipeline $GO_PL_NAME."
      EXIT_CODE=1
   else
      echo "... Succeeded to trigger the pipeline $GO_PL_NAME."
   fi
}

release_trigger_work()
{
   LAST_JOB_ID=$(curl -s -S "$GOCD_URL/go/api/jobs/Release_Trigger/Trigger/defaultJob/history" -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" | jq .jobs[0].id)
   pipeline_trigger Release_Trigger
   sleep 10
   NEW_JOB_ID=$(curl -s -S "$GOCD_URL/go/api/jobs/Release_Trigger/Trigger/defaultJob/history" -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" | jq .jobs[0].id)
   if [ "$NEW_JOB_ID" -gt "$LAST_JOB_ID" ] ; then
      NEW_JOB_RESULT=""
      while echo $NEW_JOB_RESULT | grep -iv "Pass" > /dev/null 2>&1
      do
         sleep 5
         NEW_JOB_RESULT=$(curl -s -S "$GOCD_URL/go/api/jobs/Release_Trigger/Trigger/defaultJob/history" -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" | jq -r .jobs[0].result)
         echo -e "job status: $NEW_JOB_RESULT"
      done
   fi
}

pipeline_conf()
{
   echo -e "\nRead Go pipeline configuration:"; sleep 1
   PL_NAME=$1
   PL_CONF=$2

   curl -s -S "$GOCD_URL/go/api/admin/pipelines/$PL_NAME" \
        -H 'Accept: application/vnd.go.cd.v5+json' \
        -u "$GOCD_ADMIN:$GOCD_ADMIN_PWD" \
        -o $PL_CONF

   if [ "$(jq -r '.name' $PL_CONF)" = "$PL_NAME" ] ; then
      echo -e "... Succeeded to read pipeline configuration."
   else
      echo -e "... Failed to read pipeline configuration."
      EXIT_CODE=1
   fi
}

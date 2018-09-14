#!/bin/bash

TIMESTAMP=$(date -u +"%Y-%m-%d-%H%M-%Z")
TEAM_LST=list_team_${TIMESTAMP}.txt
TEAM_ALL_LST=whole_list_team_${TIMESTAMP}.csv
USER_LOGIN_ID_LST=whole_list_user_login_ID_${TIMESTAMP}.txt
USER_LOGIN_ID_NAME_EMAIL_LST=whole_list_user_login_id_name_email_${TIMESTAMP}.csv

LOG_DIR=logs_${TIMESTAMP}
mkdir $LOG_DIR

######################################################################################
echo -e "\nGenerate a list of the whole user login ID ..."

LOOP_NR=0
GITHUB_DATA=null
while [ ! -z "$GITHUB_DATA" ]
do
  LOOP_NR=$((LOOP_NR+1))
  curl -sS -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API/orgs/mdsol/members?page=${LOOP_NR}&per_page=100" > $LOG_DIR/users_${LOOP_NR}.json
  GITHUB_DATA=$(jq '.[]' $LOG_DIR/users_${LOOP_NR}.json)
  cat $LOG_DIR/users_${LOOP_NR}.json | jq -r ".[].login" >> $USER_LOGIN_ID_LST
done

######################################################################################
echo "Generate a list of the whole user login ID associated with Email address ..."

cat $USER_LOGIN_ID_LST | while read login_id
do
  rm -f user_profile.json
  curl -sS -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API/users/$login_id" > user_profile.json
  jq -r '. | ",\(.login),\(.name),\(.email)"' user_profile.json >> $USER_LOGIN_ID_NAME_EMAIL_LST
done

######################################################################################
echo "Generate a list of mdsol teams ..."

LOOP_NR=0
GITHUB_DATA=null
while [ ! -z "$GITHUB_DATA" ]
do
  LOOP_NR=$((LOOP_NR+1))
  curl -sS -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API/orgs/mdsol/teams?page=${LOOP_NR}&per_page=100" > $LOG_DIR/teams_${LOOP_NR}.json
  GITHUB_DATA=$(jq '.[]' $LOG_DIR/teams_${LOOP_NR}.json)
  jq -r '.[] | "\(.id) \"\(.name)\""' $LOG_DIR/teams_${LOOP_NR}.json >> $TEAM_LST
done

######################################################################################
echo "Generate a CSV of all mdsol teams ..."

cat $TEAM_LST | while read team_id team_name
do
  team_name_full=$(echo $team_name | tr '"' '_' | tr ' ' '_' | tr '/' '_')
  LOOP_NR=0
  GITHUB_DATA=null
  while [ ! -z "$GITHUB_DATA" ]
  do
    LOOP_NR=$((LOOP_NR+1))
    curl -sS -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API/teams/$team_id/members?page=${LOOP_NR}&per_page=100" > $LOG_DIR/${team_id}_team_users_${LOOP_NR}.json
    GITHUB_DATA=$(jq '.[]' $LOG_DIR/${team_id}_team_users_${LOOP_NR}.json)
    cat $LOG_DIR/${team_id}_team_users_${LOOP_NR}.json | jq -r ".[].login" >> $LOG_DIR/Team_${team_name_full}_Users.txt
  done

  TEAM_USER_LST=Team_${team_name_full}_${TIMESTAMP}.csv
  echo -e ",LOGIN,NAME,EMAIL" > $TEAM_USER_LST
  cat $LOG_DIR/Team_${team_name_full}_Users.txt | while read team_user_login_id
  do
    grep $team_user_login_id $USER_LOGIN_ID_NAME_EMAIL_LST >> $TEAM_USER_LST
  done
  echo "TEAM $team_name,,," >> $TEAM_ALL_LST
  cat $TEAM_USER_LST >> $TEAM_ALL_LST 
done
rm -f user_profile.json

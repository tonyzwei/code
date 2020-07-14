#!/bin/bash

chk_dpkg()
{
  echo -e "\nChecking dpkg locks..."
  DPKG_LOCK=ON
  while [ "$DPKG_LOCK" = "ON" ]
  do
    sleep 5
    if sudo fuser /var/lib/dpkg/lock || sudo fuser /var/lib/dpkg/lock-frontend; then
       DPKG_LOCK=ON
    else
       DPKG_LOCK=OFF
    fi
    if [ "$DPKG_LOCK" = "OFF" ]; then
       sleep 5
       sudo fuser /var/lib/dpkg/lock || sudo fuser /var/lib/dpkg/lock-frontend && DPKG_LOCK=ON
    fi
  done
  echo -e "dpkg locks are cleaned.\n"
}

update_permissions()
{
  echo -e "\nUpdate permissions of files and directories, it takes a while ...\n"
  # $2 directory permission level: 755 (regular) or 2755 (pip)

  sudo find $1 -type d | while read mydir;  do sudo chmod $2 "$mydir"; done
  sudo find $1 -type f | while read myfile; do sudo chmod a+r "$myfile"; done
  sudo find $1 -type f | while read myfile; do
    if sudo getfacl -cp "$myfile" | grep "x" > /dev/null; then
       sudo chmod a+x "$myfile"
    fi
  done
}

update_permissions_file()
{
  sudo chown root:root $1
  sudo chown 755       $1
}

chk_dpkg
sudo apt-get -y install software-properties-common

echo "debconf debconf/frontend select Noninteractive" | sudo debconf-set-selections

chk_dpkg
sudo apt-get upgrade -y

chk_dpkg
sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
chk_dpkg

sudo apt-get install python3-dev -y
sudo apt-get install python3-setuptools -y
sudo apt-get install python3-pip -y

sudo -H pip3 install ansible==2.9.9
sudo -H pip3 install awscli Markdown pywinrm boto boto3 botocore awsretry requests

PYTHON3_VERSION_FULL=$(python3 -V | awk '{print $2}')
PYTHON3_VERSION=$(echo ${PYTHON3_VERSION_FULL:0:3})
update_permissions /usr/local/lib/python${PYTHON3_VERSION}/dist-packages 2755
sudo chmod a+r $(which ansible-playbook)
sudo chmod a+r $(which ansible)

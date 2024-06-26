#!/bin/bash


# OSS Instances
# Expected Format
#instanceA:wyckoff.grafana.net:glc_ey******TE
#instanceB:wyckoff.grafana.net:glc_ey*****iN
FILE="ossInstances.txt"

#knicks:wyckoff.grafana.net:glsa_p********dc


# Check if the file exists
if [ ! -f "$FILE" ]; then
    echo "File $FILE not found!"
    exit 1
fi

#
# Loop through each line in the file and download the dashboards and folders.
# while IFS=: read -r instance url token _; do
#     # Print the parsed values
#     echo "Instance: $instance"
#     echo "Grafana URL: $url"
#     echo "Token: $token"
#   export GRAFANA_INSTANCE=$instance
#   grr config set grafana.user api_key
#   grr config set grafana.url "https://$url"
#   grr config set grafana.token $token
#   grr config set targets Dashboard,DashboardFolder
#   grr pull $instance
# done < "$FILE"

uidMap=()

#dashboards
echo "Checking for duplicate uids in dashboards"
workingDir=$PWD
dashboards=`find $workingDir/$instance/* -name  '*.json'`
for dashboard in $dashboards; do
  uid=`jq '.spec.uid' $dashboard`
  echo $uid
  uidMap+=($uid:$dashboard)
done

echo $uidMap
echo ${#uidMap[@]}

# for dashboard in "${uidMap[@]}" ; do
#   echo #dashboard
# done  


# while IFS=: read -r instance url token; do
# jq '.spec.uid' $instance/*.json | sort | uniq -d
# done < "$FILE"





#push the dashboard to their instance folder.
#grr push -f $instance  -t Dashboards $instance





echo "Done!"

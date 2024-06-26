#!/bin/bash
exec > /dev/null

# OSS Instances
# Expected Format
#instanceA:wyckoff.grafana.net:glc_e**TE
#instanceB:wyckoff.grafana.net:glc_ey***joiN
FILE="ossInstances.txt"


#destination="knicks:wyckoff.grafana.net:glsa_p****RNR"


# Check if the file exists
if [ ! -f "$FILE" ]; then
    echo "File $FILE not found!" 
    exit 1
fi

# Check if grizzly is installed 
#https://grafana.github.io/grizzly/installation/
if ! command -v grr &> /dev/null
then
    echo "grr could not be found install it at https://grafana.github.io/grizzly/installation/"
    exit
fi


retrieve_source_dashboards() {
# Loop through each line in the file and download the dashboards and folders.
  while IFS=: read -r instance url token _; do
    export GRAFANA_INSTANCE=$instance
    grr config set grafana.user api_key
    grr config set grafana.url "https://$url"
    grr config set grafana.token "$token"
    grr pull "$instance"
    create_parent_destination_folder "$instance"
    update_all_folders "$instance"
    instances+=("$instance")
  done < "$FILE"

}

create_parent_destination_folder() {
  instance=$1
  echo "creating parent folder for $instance" >&2
  #grr picks this up as the first folder to create
  file_name="$instance/folders/0.json"
  #parent/instance folder for grizzly to create on push
cat <<EOF > "$file_name"
  {
  "apiVersion": "grizzly.grafana.com/v1alpha1",
  "kind": "DashboardFolder",
  "metadata": {
    "name": "Migrate$1"
  },
  "spec": {
    "title": "Migrate $1",
    "uid": "Migrate$1",
    "url": "/dashboards/f/$1/"
  }
}
EOF
}

#update folders to provide a hierarchy in the destination instance.
update_all_folders(){
instance=$1
echo "updating folders for $instance" >&2
parentUid=$(jq -r '.spec.uid' $instance/folders/0.json)
parentTitle=$(jq -r '.spec.title' $instance/folders/0.json)
# Loop through each file in the folders directory
for file in "$instance"/folders/folder*.json; do
    # Check if the file exists
    if [[ -f "$file" ]]; then
        metadataName=$(jq -r  '.metadata.name' $file)
        new_url="/dashboards/f/$parentUid/$metadataName/"
        jq --arg parentUid "$parentUid" '.spec.parentUid = $parentUid' "$file"  >  $$.json && mv $$.json "$file"
        jq --arg parentTitle "$parentTitle" '.spec.parents[0].title = $parentTitle' "$file"  >  $$.json && mv $$.json "$file"
        jq --arg parents "$parentUid" '.spec.parents[0].uid = $parents' "$file"  >  $$.json && mv $$.json "$file"
        jq --arg new_url "$new_url" '.spec.url = $new_url' "$file"  >  $$.json && mv $$.json "$file"
    fi
done

}

check_for_duplicate_uids() {
  echo "checking for duplicate uids" >&2
  # Check for duplicate UIDs
  uids=()
  instance=()
  while IFS=: read -r instance _; do
  instances+=("$instance")
  done < $FILE

  # Initialize the variable to hold the dashboard files
  dashboard_files=""

  # Loop through each directory
  workingDir=$PWD
  for inst in "${instances[@]}"; do
      # Find .json files in the current directory and append them to dashboard_files variable
      while IFS= read -r -d '' file; do
          dashboard_files+="$file"$'\n'
      done < <(find "$workingDir/$inst/dashboards" -name '*.json' -print0)
  done

  for dashboard in $dashboard_files; do
    uid=$(jq -r '.spec.uid' "$dashboard")
    uid="${uid//-}"
    uids+=("$uid")
  done

  duplicates=$(printf "%s\n" "${uids[@]}" | sort  | uniq -d)

  #convert the duplicates uids into an array
  while IFS= read -r line; do
    dups+=("$line")
  done <<< "$duplicates"

duplicates=$(printf "%s\n" "${uids[@]}" | sort  | uniq -d)



# Loop through each string and check if it exists in the file

if [ "${#dups[@]}" -gt 1 ]; then
    for file in $dashboard_files; do
      currentUid=$(jq -r '.spec.uid' "$file")
      if printf '%s\n' "${dups[@]}" | grep -q "^$currentUid$"; then
        new_uid=$(uuidgen)
        jq --arg new_uid "$new_uid" '.spec.uid = $new_uid' "$file" >  "$new_uid".$$.json && mv "$new_uid".$$.json "$file"
      fi
    done

else
  echo "No duplicates found" >&2
fi
}

#upload dashboards to new instance
upload_dashboards() {
  echo "uploading dashboards to destination instance" >&2
  instances=()
  # Extract the first item before the first colon
  # Add the first item to the array
  while IFS=: read -r instance _; do
  instances+=("$instance")
  done < $FILE
  for inst in "${instances[@]}"; do
  echo "uploading dashboards for $inst" >&2
  # before uploading dashboards to the destination instance, update any dashboards in the general folder to the new instance folder
    general_directory="$inst/dashboards/general"
    general_folder_name="Migrate$inst"
    for file in "$general_directory"/*.json; do
      if [[ -f "$file" ]]; then
        jq --arg folder "$general_folder_name" '.metadata.folder = $folder' "$file"  >  $$.json && mv $$.json "$file"
      fi
    done


    grr config create-context destination
    grr config set grafana.user api_key
    grr config set grafana.url "https://knicks.grafana.net"
    grr config set grafana.token "glsa_***Lm"
    grr config set targets Dashboard,DashboardFolder
    grr config set output-format json
    grr push "$inst"/folders/
    grr push "$inst"/dashboards/
  done
}


#workflow to migrate dashboards from one or many instance to another
retrieve_source_dashboards
check_for_duplicate_uids
upload_dashboards

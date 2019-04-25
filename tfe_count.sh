#!/bin/bash

TFE_SERVER="${TFE_SERVER:-app.terraform.io}"
TFE_API_VERSION="${TFE_API_VERSION:-v2}"

# Required: TFE Organization
if [[ -z "$TFE_ORG" ]]; then
  echo 'ERROR: $TFE_ORG is not set' 1>&2
  exit 1
fi

# Required: TFE token
if [[ -z "$TFE_TOKEN" ]]; then
  echo 'ERROR: $TFE_TOKEN is not set' 1>&2
  exit 1
fi

# Required: TFE type to count
if [[ -z "$1" ]]; then
  echo 'ERROR: Supply the resource type as an argument' 1>&2
  exit 1
fi
TFE_TYPE=$1

# http_call(method, url, {data}, expected_error_codes)
RESPONSE=$(mktemp -t tfe_count)
http_call() {
  status=$(curl -sk \
    --header "Authorization: Bearer $TFE_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --data "$3" \
    --request $1 \
    -w %{http_code} \
    -o $RESPONSE \
    "$2")
  # Set acceptable exit codes
  if [[ -z "$4" ]]; then
    error_codes=(200 204)
  else
    # Expand to bash array
    error_codes=($(echo $4 | tr ',' ' '))
  fi
  # Check if status code is acceptable
  if [[ " ${error_codes[*]} " == *" ${status} "* ]]; then
    cat $RESPONSE
  else
    echo "ERROR: Response code: ${status}. $(cat $RESPONSE)" 1>&2
    return 1
  fi
}

# tfe_api(method, endpoint, {data}, expected_error_codes)
tfe_api() {
  ret=$(http_call $1 "https://${TFE_SERVER}/api/${TFE_API_VERSION}/$2" "$3" $4)
  [ $? -ne 1 ] && echo $ret || return 1 # Stop if cURL fail
}

# Grab timestamp
NOW=$(date)

# Space-separated list of workspace IDs and names
get_workspace_list=$(tfe_api GET organizations/$TFE_ORG/workspaces)
[ $? -ne 1 ] || exit $?
workspace_list=$(echo $get_workspace_list | jq -r '[.data[] | { "id": .id, "name": .attributes.name }]')

TOTAL=0

# Construct JSON string
json='{'
for row in $(echo "${workspace_list}" | jq -r '.[] | @base64'); do
  # Breakdown ID and name
  ws_id=$(echo $row | base64 --decode | jq -r '.id')
  ws_name=$(echo $row | base64 --decode | jq -r '.name')
  echo "Reviewing workspace '${ws_name}'..." 1>&2
  json="${json} \"${ws_id}\": {"
  json="${json} \"name\": \"${ws_name}\""

  # Find state URL
  # Need 404 status code in case workspace has no state yet`
  get_state_url=$(tfe_api GET workspaces/$ws_id/current-state-version {} '200,204,404')
  [ $? -ne 1 ] || exit $?
  state_url=$(echo $get_state_url | jq -r '.data.attributes."hosted-state-download-url"')
  json="${json}, \"state_url\": \"${state_url}\""

  # Check for state file
  if [ "$state_url" == "null" ]; then
    count=0
  else
    # Grab state from URL
    current_state=$(http_call GET $state_url)

    # Filter for target resource type
    targets=$(echo $current_state | jq --arg TFE_TYPE "$TFE_TYPE" '.modules[].resources | to_entries[] | select (.value.type == $TFE_TYPE) | .key')

    # Handle empty variable and count
    if [[ -z "$targets" ]]; then
      count=0
    else
      targets_array=$(echo "$targets" | tr '\n' ',' | sed 's/,$//')
      json="${json}, \"targets\": [ ${targets_array} ]"
      count=$(echo "$targets" | sed -n '$=')
    fi
  fi
  #json="${json}, \"type\": \"${TFE_TYPE}\""
  json="${json}, \"count\": ${count}"
  json="${json} },"

  # Incrememt total
  TOTAL=$((TOTAL+count))
done
# Remove trailing comma
json=$(echo $json | sed 's/,$//')
json="${json} }"

echo "[ $json, { \"timestamp\": \"${NOW}\", \"organization\": \"${TFE_ORG}\", \"type\": \"${TFE_TYPE}\", \"total\": ${TOTAL} }]"

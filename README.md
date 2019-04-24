# Terraform Enterprise Resource Counter

## Overview

This script is meant to answer the question:
>How many $type am I currently running in my TFE org?

## Setup

You'll need two environment variables to get started. There are some optional ones as well.

* `TFE_ORG`: The name of the TFE organization to be targeted
* `TFE_TOKEN`: A token which has access to pull workspaces and statefiles
* `TFE_SERVER` (optional): DNS name to TFE server <br>Default: `app.terraform.io`
* `TFE_API_VERSION` (optional): Version of the TFE api to use
<br>Default: `v2`

## Example

```
# export TFE_ORG=WhatsARanjit
# export TFE_TOKEN=XXXXXXXXXXXXXXX
# ./tfe_count.sh aws_instance
```

## Expected output

```
# ./tfe_count.sh aws_instance | jq
Reviewing workspace 'aws-test-environment'...
Reviewing workspace 'azure-test-environment'...
[
  {
    "ws-IWhHyw7PtAzbpaDn": {
      "name": "aws-test-environment",
      "state_url": "https://archivist.terraform.io/v1/object/reallylongstateURL",
      "targets": [
        "aws_instance.ubuntu",
        "aws_instance.web"
      ],
      "count": 2
    },
    "ws-24bmknxHEqu55yms": {
      "name": "azure-test-environment",
      "state_url": "https://archivist.terraform.io/v1/object/reallylongstateURL",
      "count": 0
    },
  {
    "timestamp": "Wed Apr 24 08:17:01 EDT 2019",
    "organization": "WhatsARanjit",
    "type": "aws_instance",
    "total": 2
  }
]
```

**NOTE:** The lines beginning with "Reviewing" in the output are printed for status, but do not get captured in `STDOUT`.

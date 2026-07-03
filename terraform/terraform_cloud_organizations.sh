Terraform Cloud-এর API-এর সাথে কথা বলার সময়, তারা আপনাকে সরাসরি আপনার কোম্পানির নাম দিয়ে চিনবে না। তারা চিনে Unique ID দিয়ে।
​যখনই আপনি অন্য কোনো অটোমেশন স্ক্রিপ্ট চালাবেন (যেমন: ওয়ার্কস্পেসের তালিকা দেখা, ভেরিয়েবল আপডেট করা বা অডিট করা), সেই স্ক্রিপ্টগুলো আপনাকে বলবে: "আগে আমাকে বলো কোন অর্গানাইজেশনের আইডি নিয়ে কাজ করতে হবে।"
​এই স্ক্রিপ্টটি হলো সেই "আইডি সরবরাহকারী" (ID Provider)।

https://mega.nz/file/12A2AAyJ#52aF1lG_92zbADWyqtowligMB4uk_2tk4yjVThMjrT4



#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#  args:
#
#  Author: Hari Sekhon
#  Date: 2021-12-21 13:30:39 +0000 (Tue, 21 Dec 2021)
#
#  https://github.com/HariSekhon/DevOps-Bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

# https://www.terraform.io/cloud-docs/api-docs/organizations

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090,SC1091
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Lists Terraform Cloud organization IDs (needed by many adjacent scripts)

Output:

<id>
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args=""

help_usage "$@"

#min_args 1 "$@"

# TODO: add pagination support
"$srcdir/terraform_cloud_api.sh" "/organizations" |
jq_debug_pipe_dump |
jq -r '.data[].id'

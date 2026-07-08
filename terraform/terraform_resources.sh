
ধরে নিন, আপনার কোম্পানিতে ১০০টি GitHub Repository (কোড রাখার জায়গা) আছে। আপনার কাজ হলো এই ১০০টি রিপোজিটরিকে একটি নির্দিষ্ট টিম বা দলের (DevOps Team) সাথে যুক্ত করা, যেন তারা এই প্রজেক্টগুলোর অ্যাডমিন হতে পারে।

সমস্যা:
Terraform-এ আপনি যদি সরাসরি সব GitHub রিপোজিটরির লিস্ট নিয়ে লুপ (for_each) চালাতে চান, তবে Terraform-এর স্প্ল্যাট এক্সপ্রেশন ([*]) কিছু জটিলতার কারণে আপনাকে সরাসরি টপ-লেভেল রিসোর্সের আইডি এবং নামের ম্যাপিং একসাথে দিতে দেয় না (এটি Terraform-এর একটি সুপরিচিত ইস্যু #19931)।

সমাধান (এই স্ক্রিপ্টের কাজ):
এই স্ক্রিপ্টটি ব্যাকগ্রাউন্ডে Terraform-এর বর্তমান স্টেট (State) চেক করে। সে একটি তালিকা তৈরি করে, যেখানে প্রতিটা রিপোজিটরির ID এবং তার Name জোড়ায় জোড়ায় (Key-Value Pair) থাকে। যেমন:

JSON
{
  "repo-id-123": "frontend-app",
  "repo-id-456": "backend-api"
}
এরপর Terraform এই তালিকাটি দেখে খুব সহজেই for_each লুপ চালিয়ে সব রিপোজিটরিকে একবারে DevOps টিমের সাথে যুক্ত করে দিতে পারে।


#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2022-02-28 19:18:26 +0000 (Mon, 28 Feb 2022)
#
#  https://github.com/HariSekhon/DevOps-Bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x

# sourcing lib.sh results in Terraform errors 'is_verbose: command not found'

usage="
Terraform external program that returns a list of resource ids and attribute for a given resource_type

Workaround for Terraform Splat expressions not supporting top level resources

    https://github.com/hashicorp/terraform/issues/19931

Returns a JSON output in format 'map[string]=string' where the key is set to the id and the value is set to the name or selected attribute value of the resource

Returns a non-zero error code if the resource_type is not found which will be picked up by Terraform to error out, but a missing attribute will get a null value


Example:

    ${0##*/} github_repository

Terraform:

    data \"external\" \"github_repos\" {
        program = [\"/path/to/${0##*/}\", \"github_repository\"]
    }

    resource \"github_team_repository\" \"devops\" {
      permission = \"admin\"
      for_each   = data.external.github_repos.result
      repository = each.key
      team_id    = github_team.devops.id
    }


Requires Terraform and jq to be installed and configured


usage: ${0##*/} <resource_type> [<attribute>]
"

if [ $# -lt 1 ] ||
   [ $# -gt 2 ] ||
   [[ "$1" =~ ^- ]] ||
   [[ "${2:-}" =~ ^- ]]; then
    echo "$usage"
    exit 3
fi

resource_type="$1"
attribute="${2:-name}"

#terraform state list  |
#grep "^$resource_type\\." |
#awk -F. '{print $2}' |
#while read -r resource; do
#    # Terraform state outputs control chars, remove them so grep will work - hard to remove all escape sequences and slow
#    # we need literal escapes here
#    # shellcheck disable=SC1117
#    terraform state show "$resource_type.$resource" |
#    sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" |
#    # nested attributes, eg. branches have greater depth - this code is brittle but Terraform doesn't support -json for terraform state show unfortunately
#    grep -E "^    ${attribute}[[:space:]]+= " |
#    awk -F= '{print $2}' |
#    sed 's/^"//;s/"$//'
#done |

terraform show -json -no-color |
jq -er "
    .values.root_module |
      [
        .resources[],
        .child_modules[].resources[]
      ] |
    flatten[] |
    select(.type == \"$resource_type\") |
    select(.values.id) |
    { (.values.id) : .values.$attribute }" |
jq -en 'reduce inputs as $in (null; . + $in)'

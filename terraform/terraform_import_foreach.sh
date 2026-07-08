ধরুন, আপনার কাছে ১০টি GitHub Repository আছে। আপনি চাচ্ছেন এই ১০টি রেপোতেই একটি সাধারণ ব্রাঞ্চ তৈরি করবেন, যার নাম হবে main বা development।

টেরাফর্মে আপনি হয়তো এভাবে কোড লিখেছেন:

Terraform
resource "github_branch" "engineering" {
  for_each   = toset(["repo-alpha", "repo-beta", "repo-gamma"])
  repository = each.value
  branch     = "development"
}
এখানে খেয়াল করুন, আপনি রিসোর্স তৈরি করছেন একটি (github_branch), কিন্তু লুপের কারণে ব্যাকএন্ডে ৩টি আলাদা আলাদা ব্রাঞ্চ ট্র্যাক হচ্ছে।

সমস্যা:
টেরাফর্ম যখন এর প্ল্যান বা স্টেট তৈরি করে, তখন সে এটিকে এভাবে লেখে:
github_branch.engineering["repo-alpha"]

এখন এটি যদি ক্লাউডে আগে থেকেই তৈরি করা থাকে, তবে একে ইম্পোর্ট করতে হলে আপনাকে টেরাফর্মের নিয়ম অনুযায়ী দুটি তথ্য মিলিয়ে একটি আইডি (Composite ID) দিতে হবে, যা দেখতে এমন হয়:

Bash
terraform import 'github_branch.engineering["repo-alpha"]' repo-alpha:development
এখানে repo-alpha (রেপোর নাম) এবং development (ব্রাঞ্চের নাম) কোলন (:) দিয়ে জোড়া দিতে হয়েছে। ম্যানুয়ালি এরকম শত শত লুপের রিসোর্স ইম্পোর্ট করা এক প্রকার দুঃস্বপ্ন।

সমাধান (এই স্ক্রিপ্টের কাজ):
এই স্ক্রিপ্টটি রান করার সময় আপনি যে রিসোর্স টাইপ লিখে দেবেন (যেমন: github_branch), সে terraform plan থেকে লুপের ভেতরের সেই হিজিবিজি নামগুলো খুঁজে বের করবে এবং কোলন (:) দিয়ে আসল আইডি বানিয়ে এক ক্লিকে ইম্পোর্ট করে দেবে।


#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2022-02-25 18:14:24 +0000 (Fri, 25 Feb 2022)
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
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090,SC1091
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Finds all given for_each generated resource references in Terraform plan output not in Terraform state and imports them

Will do nothing if the resource_type you specify doesn't match anything in the local code eg. 'github_repo' won't match, it must be the terraform type 'github_repository'

This is a general case importer that will only cover basic use cases such as GitHub repos where the names usually match the terraform IDs
(except for things like '.github' repo which is not a valid terraform identifier. Those must still be imported manually)

If \$TERRAFORM_PRINT_ONLY is set to any value, prints the commands to stdout to collect so you can check, collect into a text file or pipe to a shell or further manipulate, ignore errors etc.


Requires Terraform to be installed and configured
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="<resource_type> [<dir>]"

help_usage "$@"

min_args 1 "$@"

resource_type="$1"
dir="${2:-.}"

cd "$dir"

timestamp "getting terraform plan"
plan="$(terraform plan -no-color)"
echo >&2

timestamp "getting '$resource_type' from terraform plan output"
grep -E "^[[:space:]]*# $resource_type\\..+\\[\"[^\"]+\"\\] will be created" <<< "$plan" |
awk '{print $2}' |
while read -r resource_path; do
    echo >&2
    # <resource_type>.resource2[resource1] - resource 1 is usually the differentiator, eg. github repo, whereas resource2 is usually what is applied to each one, such as the same branch
    resource1="${resource_path##*[\"}"
    resource1="${resource1%%\"]*}"
    resource2="${resource_path%%[*}"
    resource2="${resource2##*.}"
    cmd=(terraform import "$resource_path" "$resource1:$resource2")
    timestamp "${cmd[*]}"
    if [ -z "${TERRAFORM_PRINT_ONLY:-}" ]; then
        "${cmd[@]}"
    fi
done

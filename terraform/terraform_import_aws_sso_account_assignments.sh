আপনার এন্টারপ্রাইজ বা কোম্পানিতে AWS Identity Center-এর মাধ্যমে কোন ইউজার বা গ্রুপ কোন AWS অ্যাকাউন্টের কী পারমিশন পাবে (Account Assignment), তা যদি আগে থেকে ম্যানুয়ালি সেট করা থাকে—তবে এই স্ক্রিপ্টটি স্বয়ংক্রিয়ভাবে terraform plan থেকে সেই জটিল ম্যাপিংগুলো স্ক্র্যাপ করে এক ক্লিকে Terraform State-এ ইম্পোর্ট করে দেয়।

নিচে এর পেছনের মূল সমস্যা এবং স্ক্রিপ্টটির কার্যপ্রণালী গভীরভাবে ব্যাখ্যা করা হলো।

১. বাস্তব জীবনের জটিল সমস্যা (The AWS Identity Center Challenge)
বড় বড় কোম্পানিতে (এন্টারপ্রাইজ লেভেলে) শত শত AWS অ্যাকাউন্ট থাকে। কোন ইউজার কোন অ্যাকাউন্টে ঢুকতে পারবে, তা নিয়ন্ত্রণ করতে AWS Identity Center ব্যবহার করা হয়। এখানে একটি রিসোর্স তৈরি করতে হয় যাকে বলে aws_ssoadmin_account_assignment।

সমস্যা:
Terraform-এ এই রিসোর্সটি ইম্পোর্ট করা এক প্রকার দুঃস্বপ্ন। কারণ একে ইম্পোর্ট করতে হলে আপনাকে ৬টি আলাদা আলাদা প্যারামিটার বা আইডি কমা (,) দিয়ে জোড়া লাগিয়ে একটি বিশাল "Composite ID" বানাতে হয়! Terraform-এর নিয়ম অনুযায়ী কমান্ডটি দেখতে এমন হয়:

Bash
terraform import aws_ssoadmin_account_assignment.my_assignment <principal_id>,<principal_type>,<target_id>,<target_type>,<permission_set_arn>,<instance_arn>
এই ৬টি তথ্যের মধ্যে রয়েছে:

principal_id: ইউজারের আইডি বা গ্রুপের আইডি।

principal_type: এটি কি ইউজার নাকি গ্রুপ (USER বা GROUP)।

target_id: কোন AWS অ্যাকাউন্টে অ্যাক্সেস দেওয়া হচ্ছে (Account ID)।

target_type: ডিফল্টভাবে এটি AWS_ACCOUNT হয়।

permission_set_arn: সে কী পারমিশন পাবে (যেমন: AdministratorAccess-এর ARN)।

instance_arn: আইডেন্টিটি সেন্টারের মেইন ইন্সট্যান্স ARN।

ম্যানুয়ালি এই ৬টি বড় বড় টেক্সট ও আইডি খুঁজে বের করে, কমা দিয়ে সাজিয়ে, ২০-৩০টি অ্যাসাইনমেন্ট ইম্পোর্ট করা মানুষের পক্ষে প্রায় অসম্ভব এবং অত্যন্ত ভুল হওয়ার মতো কাজ।

সমাধান (এই স্ক্রিপ্টের কাজ):
এই স্ক্রিপ্টটি রান করলে সে নিজে থেকেই ব্যাকগ্রাউন্ডে terraform plan চালায়। প্ল্যানের আউটপুটে এই ৬টি তথ্যই সুন্দরভাবে লেখা থাকে। স্ক্রিপ্টটি বুদ্ধিমত্তার সাথে সেই ৬টি ভ্যালু স্ক্র্যাপ করে, কমা দিয়ে জোড়া লাগিয়ে নিখুঁত আইডি তৈরি করে এক সেকেন্ডে ইম্পোর্ট সম্পন্ন করে।

#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2022-09-20 16:24:51 +0100 (Tue, 20 Sep 2022)
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
Parses Terraform Plan for aws_ssoadmin_account_assignment additions and imports each one into Terraform state

If \$TERRAFORM_PRINT_ONLY is set to any value, prints the commands to stdout to collect so you can check, collect into a text file or pipe to a shell or further manipulate, ignore errors etc.


Requires Terraform to be installed and configured
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<dir>]"

help_usage "$@"

dir="${1:-.}"

cd "$dir"

#TMP_PLAN="$(mktemp)"
#TMP_PLAN_JSON="$(mktemp)"

#timestamp "Getting Terraform Plan"
#terraform plan -out "$TMP_PLAN"
#echo >&2
#
#timestamp "Parsing Terraform Plan"
## have to parse references, and then double parse to find the values of the object references :-/
#terraform show -json "$TMP_PLAN" |
#jq -Mr > "$TMP_PLAN_JSON"

#jq -Mr <"$TMP_PLAN_JSON" '
#    .configuration.root_module.resources[] |
#    select(.type == "aws_ssoadmin_account_assignment") |
#    [.address, ] |
#    @tsv' |

terraform plan -no-color |
#grep -FA8 '+ resource "aws_ssoadmin_account_assignment" ' |
sed -n '/# aws_ssoadmin_account_assignment\..* will be created/,/}/ p' |
awk '/# aws_ssoadmin_account_assignment/ {print $2};
     /instance_arn|permission_set_arn|principal_id|principal_type|target_id/ {print $4}' |
sed 's/^"//; s/"$//' |
xargs -n6 echo |
sed 's/\[/["/; s/\]/"]/' |
while read -r name instance_arn permission_set_arn principal_id principal_type target_id; do
    [ -n "$target_id" ] || continue
    timestamp "Importing $name"
    cmd=(terraform import "$name" "$principal_id,$principal_type,$target_id,AWS_ACCOUNT,$permission_set_arn,$instance_arn")
    timestamp "${cmd[*]}"
    if [ -z "${TERRAFORM_PRINT_ONLY:-}" ]; then
        "${cmd[@]}"
    fi
    echo >&2
done

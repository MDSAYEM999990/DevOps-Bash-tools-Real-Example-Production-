AWS Identity Center-এর কোনো নির্দিষ্ট Permission Set-এর ভেতরে যদি কোনো কাস্টম ইনলাইন পলিসি (Inline Policy - যা সরাসরি JSON কোড লিখে দেওয়া হয়) ম্যানুয়ালি সেট করা থাকে—তবে এই স্ক্রিপ্টটি স্বয়ংক্রিয়ভাবে terraform plan থেকে সেই ডেটা স্ক্র্যাপ করে এক ক্লিকে Terraform State-এ ইম্পোর্ট করে দেয়।

নিচে এর পেছনের মূল সমস্যা এবং স্ক্রিপ্টের নিখুঁত কার্যপ্রণালী গভীরভাবে ব্যাখ্যা করা হলো।

১. বাস্তব জীবনের জটিল সমস্যা (The Inline Policy Challenge)
AWS Identity Center-এ পারমিশন সেট করার সময় দুই ধরণের পলিসি ব্যবহার করা যায়:

Managed Policy: (আগের স্ক্রিপ্টটি) যা আগে থেকেই তৈরি করা থাকে, শুধু লিঙ্ক করে দেওয়া হয়।

Inline Policy: (এই স্ক্রিপ্টটি) যেখানে আপনি নিজেই সরাসরি নির্দিষ্ট কিছু পারমিশনের জন্য কাঁচা JSON কোড লিখে দেন।

সমস্যা:
টেরাফর্মে এই ইনলাইন পলিসি ইম্পোর্ট করার নিয়মটি বেশ ট্রিকি। একে ইম্পোর্ট করতে হলে আপনাকে ২টি বড় বড় ARN বা আইডি কমা (,) দিয়ে জোড়া লাগিয়ে একটি "Composite ID" বানাতে হয়:

Bash
terraform import aws_ssoadmin_permission_set_inline_policy.example <permission_set_arn>,<instance_arn>
এই দুটি তথ্য হলো:

permission_set_arn: যে নির্দিষ্ট পারমিশন সেটের ভেতর ইনলাইন পলিসিটি লেখা আছে, তার পুরো ARN।

instance_arn: আইডেন্টিটি সেন্টারের মেইন ইন্সট্যান্স ARN।

যেহেতু ইনলাইন পলিসিগুলো কোনো আলাদা স্বাধীন রিসোর্স নয় (এরা পারমিশন সেটের ভেতরেই লুকিয়ে থাকে), তাই ম্যানুয়ালি এগুলোকে খুঁজে বের করে একটি একটি করে ইম্পোর্ট কমান্ড সাজানো বেশ ঝামেলার।

সমাধান (এই স্ক্রিপ্টের কাজ):
এই স্ক্রিপ্টটি রান করলে সে ব্যাকগ্রাউন্ডে terraform plan চালায়। প্ল্যানের টেক্সট আউটপুটে এই ২টি তথ্যই খুব সুন্দরভাবে উল্লেখ করা থাকে। স্ক্রিপ্টটি বুদ্ধিমত্তার সাথে সেই ভ্যালুগুলো স্ক্র্যাপ করে, কমা দিয়ে জোড়া লাগিয়ে নিখুঁত আইডি তৈরি করে ১ সেকেন্ডে ইম্পোর্ট সম্পন্ন করে।


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
Parses Terraform Plan for aws_ssoadmin_permission_set_inline_policy additions and imports each one into Terraform state

If \$TERRAFORM_PRINT_ONLY is set to any value, prints the commands to stdout to collect so you can check, collect into a text file or pipe to a shell or further manipulate, ignore errors etc.


Requires Terraform to be installed and configured
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<dir>]"

help_usage "$@"

dir="${1:-.}"

cd "$dir"

# would have to parse references, and then double parse to find the values of the object references :-/
#terraform show -json "$TMP_PLAN" |

terraform plan -no-color |
sed -n '/# aws_ssoadmin_permission_set_inline_policy\..* will be created/,/permission_set_arn/ p' |
awk '/# aws_ssoadmin_permission_set_inline_policy/ {print $2};
     /instance_arn|permission_set_arn/ {print $4}' |
sed 's/^"//; s/"$//' |
xargs -n3 echo |
sed 's/\[/["/; s/\]/"]/' |
while read -r name instance_arn permission_set_arn; do
    [ -n "$permission_set_arn" ] || continue
    timestamp "Importing $name"
    cmd=(terraform import "$name" "$permission_set_arn,$instance_arn")
    timestamp "${cmd[*]}"
    if [ -z "${TERRAFORM_PRINT_ONLY:-}" ]; then
        "${cmd[@]}"
    fi
    echo >&2
done

AWS Identity Center-এর কোনো নির্দিষ্ট Permission Set বা প্রোফাইলের সাথে যদি AWS-এর কোনো রেডিমেড বা কাস্টম পলিসি (যেমন: AdministratorAccess বা ReadOnlyAccess) ম্যানুয়ালি যুক্ত করা থাকে—তবে এই স্ক্রিপ্টটি স্বয়ংক্রিয়ভাবে terraform plan থেকে সেই জটিল লিঙ্কিংগুলো স্ক্র্যাপ করে এক ক্লিকে Terraform State-এ ইম্পোর্ট করে দেয়।

নিচে এর পেছনের মূল সমস্যা এবং স্ক্রিপ্টটির কার্যপ্রণালী গভীরভাবে ব্যাখ্যা করা হলো।

১. বাস্তব জীবনের জটিল সমস্যা (The Managed Policy Attachment Challenge)
AWS Identity Center-এ যখন আপনি কোনো পারমিশন সেট তৈরি করেন, তখন তার সাথে কোনো না কোনো পলিসি অ্যাটাচ বা যুক্ত করতে হয়। টেরাফর্মে এই কাজটির জন্য aws_ssoadmin_managed_policy_attachment নামক রিসোর্স ব্যবহার করা হয়।

সমস্যা:
অ্যাকাউন্ট অ্যাসাইনমেন্টের মতোই, এটিকেও ম্যানুয়ালি টেরাফর্মে ইম্পোর্ট করা এক প্রকার দুঃস্বপ্ন। কারণ একে ইম্পোর্ট করতে হলে আপনাকে ৩টি বড় বড় ARN বা আইডি কমা (,) দিয়ে জোড়া লাগিয়ে একটি "Composite ID" বানাতে হয়! Terraform-এর নিয়ম অনুযায়ী কমান্ডটি দেখতে এমন হয়:

Bash
terraform import aws_ssoadmin_managed_policy_attachment.example <managed_policy_arn>,<permission_set_arn>,<instance_arn>
এই ৩টি তথ্যের প্রতিটির সাইজ অনেক বড় বড় টেক্সট ফরম্যাটে থাকে:

managed_policy_arn: যে পলিসিটি অ্যাটাচ করা আছে তার পুরো ARN (যেমন: arn:aws:iam::aws:policy/AdministratorAccess)।

permission_set_arn: আইডেন্টিটি সেন্টারের নির্দিষ্ট পারমিশন সেটের ARN।

instance_arn: আইডেন্টিটি সেন্টারের মেইন ইন্সট্যান্স ARN।

আপনার ইনফ্রাস্ট্রাকচারে যদি এমন ৫০টি পলিসি অ্যাটাচমেন্ট থাকে, তবে কনসোল থেকে এগুলো খুঁজে খুঁজে টাইপ করে ইম্পোর্ট করতে গেলে মানুষের মাথা খারাপ হওয়ার জোগাড় হবে।

সমাধান (এই স্ক্রিপ্টের কাজ):
এই স্ক্রিপ্টটি রান করলে সে নিজে থেকেই ব্যাকগ্রাউন্ডে terraform plan চালায়। প্ল্যানের আউটপুটে এই ৩টি তথ্যই খুব সুন্দরভাবে লেখা থাকে। স্ক্রিপ্টটি বুদ্ধিমত্তার সাথে সেই ৩টি ভ্যালু স্ক্র্যাপ করে, কমা দিয়ে জোড়া লাগিয়ে নিখুঁত আইডি তৈরি করে এক সেকেন্ডে ইম্পোর্ট সম্পন্ন করে।

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

# don't do this because would have to parse references, and then double parse to find the values of the object references :-/
#terraform show -json plan.zip

terraform plan -no-color |
sed -n '/# aws_ssoadmin_managed_policy_attachment\..* will be created/,/}/ p' |
awk '/# aws_ssoadmin_managed_policy_attachment/ {print $2};
     /instance_arn|managed_policy_arn|permission_set_arn/ {print $4}' |
sed 's/^"//; s/"$//' |
xargs -n4 echo |
sed 's/\[/["/; s/\]/"]/' |
while read -r name instance_arn managed_policy_arn permission_set_arn; do
    [ -n "$permission_set_arn" ] || continue
    timestamp "Importing $name"
    cmd=(terraform import "$name" "$managed_policy_arn,$permission_set_arn,$instance_arn")
    timestamp "${cmd[*]}"
    if [ -z "${TERRAFORM_PRINT_ONLY:-}" ]; then
        "${cmd[@]}"
    fi
    echo >&2
done

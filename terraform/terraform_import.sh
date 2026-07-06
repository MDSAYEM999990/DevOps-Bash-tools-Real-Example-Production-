সবচেয়ে সহজ কথায়, এই স্ক্রিপ্টের আসল কাজ বা Main Thing হলো:

"কোড আছে কিন্তু ট্র্যাকিংয়ে নেই—এমন সব রিসোর্সকে এক ক্লিকে টেরাফর্মের ট্র্যাকিংয়ে (State File) নিয়ে আসা।"

টেরাফর্ম (Terraform) দিয়ে কোনো ক্লাউড বা গিটহাব রিসোর্স ম্যানেজ করতে চাইলে দুটি জিনিস লাগে:

রিসোর্সের কোড (.tf ফাইল)।

রিসোর্সের ট্র্যাকিং রেকর্ড (terraform.tfstate ফাইল)।

ধরা যাক, আপনার কোড ফাইলে ৫০টি গিটহাব রিপোজিটরির নাম লেখা আছে। কিন্তু কোনো কারণে টেরাফর্মের ট্র্যাকিং রেকর্ডে মাত্র ৪০টি রিপোজিটরি জমা হয়ে আছে। বাকি ১০টি রিপোজিটরি কোডে থাকা সত্ত্বেও টেরাফর্ম সেগুলোকে চিনতে পারছে না।

এই স্ক্রিপ্টটি তখন ৩টি কাজ করে:
১. খোঁজা (Scan): এটি আপনার কোড ফাইলটি পড়ে দেখে সেখানে কী কী রিসোর্স আছে।

২. তুলনা করা (Compare): এটি টেরাফর্মের বর্তমান রেকর্ডের সাথে কোডের তুলনা করে সেই ১০টি "হারিয়ে যাওয়া" বা আন-ট্র্যাকড (Untracked) রিসোর্স খুঁজে বের করে।

৩. যুক্ত করা (Bulk Import): সাধারণত এই ১০টি রিসোর্সকে ট্র্যাকিংয়ে আনতে গেলে আপনাকে ১০ বার ম্যানুয়ালি বড় বড় কমান্ড টাইপ করতে হতো। এই স্ক্রিপ্টটি একটি লুপ চালিয়ে এক সেকেন্ডে এক ক্লিকে ওই ১০টি রিসোর্সকে টেরাফর্মের ট্র্যাকিং রেকর্ডে (State) ইমপোর্ট করে দেয়।

এক লাইনে সামারি: এটি ম্যানুয়ালি বারবার terraform import কমান্ড টাইপ করার কষ্ট দূর করার একটি অটোমেশন শর্টকাট (Shortcut)।



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
Finds all given resource references in ./*.tf code not in Terraform state and imports them assuming the same resource name as Terraform ID in the code

Will do nothing if the resource_type you specify doesn't match anything in the local code eg. 'github_repo' won't match, it must be the terraform type 'github_repository'

This is a general case importer that will only cover basic use cases such as GitHub repos where the names usually match the terraform IDs
(except for things like '.github' repo which is not a valid terraform identifier. Those must still be imported manually)

If \$TERRAFORM_PLAN is set to any value, gets the resources from the Terraform Plan rather than ./*.tf
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

timestamp "getting terraform state"
terraform_state_list="$(terraform state list)"
echo >&2

if [ -n "${TERRAFORM_PLAN:-}" ]; then
    timestamp "getting terraform plan"
    plan="$(terraform plan -no-color)"
    echo >&2

    timestamp "getting '$resource_type' from terraform plan output"
    grep -E "^[[:space:]]*resource[[:space:]]+\"$resource_type\"" <<< "$plan"
else
    timestamp "getting '$resource_type' from $PWD/*.tf code"
    grep -E "^[[:space:]]*resource[[:space:]]+\"$resource_type\"" ./*.tf
fi |
awk '{gsub("\"", "", $3); print $3}' |
while read -r resource; do
    echo >&2
    if grep -q "$resource_type\\.$resource$" <<< "$terraform_state_list"; then
        echo "'$resource_type.$resource' already in terraform state, skipping..." >&2
        continue
    fi
    cmd=(terraform import "$resource_type.$resource" "$resource")
    timestamp "${cmd[*]}"
    if [ -z "${TERRAFORM_PRINT_ONLY:-}" ]; then
        "${cmd[@]}"
    fi
done

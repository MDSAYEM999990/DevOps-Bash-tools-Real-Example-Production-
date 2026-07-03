
এই স্ক্রিপ্টটি একটি নির্দিষ্ট কাজের জন্য তৈরি: Terraform Cloud কোন কোন IP অ্যাড্রেস ব্যবহার করে তা খুঁজে বের করা।
Terraform Cloud যখন আপনার ক্লাউড ইনফ্রাস্ট্রাকচারের সাথে যোগাযোগ করে (যেমন: AWS বা Azure-এ নতুন সার্ভার তৈরি করতে), তখন সেটি কিছু নির্দিষ্ট IP রেঞ্জ থেকে রিকোয়েস্ট পাঠায়। সিকিউরিটির জন্য অনেক কোম্পানি তাদের ফায়ারওয়ালে শুধু ওই নির্দিষ্ট IP-গুলোকে অনুমতি (Allowlist) দিয়ে রাখে।
এই স্ক্রিপ্টটি সেই অনুমোদিত IP-গুলোর তালিকা সরাসরি Terraform Cloud থেকে নিয়ে আসে।
যদি আপনার কোম্পানি কঠোর সিকিউরিটি পলিসি মেনে চলে, তবে আপনি সব ট্রাফিক ওপেন রাখতে পারবেন না। আপনাকে জানতে হবে Terraform Cloud ঠিক কোন IP থেকে আপনার সিস্টেমে রিকোয়েস্ট পাঠাচ্ছে।

ধরা যাক, আপনার নেটওয়ার্ক টিম বলেছে যে, "আমরা শুধু Terraform-এর API ট্রাফিক এলাউ করবো।" তখন আপনি এই কমান্ডটি চালাবেন:
./terraform_cloud_ip_ranges.sh api

এটি আউটপুট হিসেবে শুধু api ক্যাটাগরির সব IP অ্যাড্রেসগুলো দিয়ে দেবে, যা আপনি ফায়ারওয়ালে কপি-পেস্ট করতে পারবেন। কোনো কিছু না লিখলে এটি সব ধরনের (api, vcs, sentinel, notifications) IP একসাথে দিয়ে দিবে।


#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2021-12-20 13:32:36 +0000 (Mon, 20 Dec 2021)
#
#  https://github.com/HariSekhon/DevOps-Bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

# https://www.terraform.io/cloud-docs/api-docs/ip-ranges

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090,SC1091
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Returns the list of IP ranges that Terraform Cloud may use via the API

Can optionally return just the IP lists for one or more of the following range types:

    api
    notifications
    sentinel
    vcs

For more details, see:

    https://www.terraform.io/cloud-docs/api-docs/ip-ranges
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<range_type> <range_type> ...]"

help_usage "$@"

#min_args 1 "$@"

for range_type in "$@"; do
    if ! [[ "$range_type" =~ ^(api|notifications|sentinel|vcs)$ ]]; then
        usage "invalid range type given, must be one of: api, notifications, sentinel, vcs"
    fi
done

data="$(curl -sS https://app.terraform.io/api/meta/ip-ranges)"

if [ -n "${DEBUG:-}" ]; then
    jq . <<< "$data" >&2
fi

if [ $# -gt 0 ]; then
    for range_type in "$@"; do
        jq -r ".${range_type}[]" <<< "$data"
    done
else
    jq -r '.[][]' <<< "$data"
fi |
sort -u



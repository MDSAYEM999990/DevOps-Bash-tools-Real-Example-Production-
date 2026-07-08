ধরুন, আপনার কোম্পানিতে একটি বিশাল অর্গানাইজেশন আছে (যেমন: my-enterprise-org)। এর অধীনে বিভিন্ন প্রজেক্ট ও এনভায়রনমেন্টের (যেমন: dev-vpc, prod-eks, staging-database) জন্য আলাদা আলাদা ১০০টি Workspace বা ফোল্ডার তৈরি করা আছে।

সমস্যা:
১. আপনাকে যদি হঠাৎ নতুন একটি স্ক্রিপ্ট লিখতে হয় যা সব ওয়ার্কস্পেসে কোনো নির্দিষ্ট সিক্রেট বা ভ্যারিয়েবল পুশ করবে, তবে প্রথমেই আপনার সবগুলো ওয়ার্কস্পেসের নিখুঁত Workspace ID এবং Name-এর একটি তালিকা লাগবে।
২. ব্রাউজারে ঢুকে প্রতি পৃষ্ঠায় ১০-২০টি করে দেখে দেখে ১০০টি ওয়ার্কস্পেসের আইডি কপি করা অসম্ভব এবং চরম সময়সাপেক্ষ।

সমাধান (এই স্ক্রিপ্টের কাজ):
আপনি শুধু টার্মিনালে এই স্ক্রিপ্টটি আপনার অর্গানাইজেশনের নাম দিয়ে রান করবেন:

Bash
./script.sh my-enterprise-org
এটি সাথে সাথে ১ সেকেন্ডের মধ্যে আপনার স্ক্রিনে সব ওয়ার্কস্পেসের আইডি এবং নামের একটি চমৎকার লিস্ট প্রিন্ট করে দেবে।

#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#  args:
#  args: :org
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

# https://www.terraform.io/cloud-docs/api-docs/workspaces

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090,SC1091
. "$srcdir/lib/utils.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Lists Terraform Cloud workspaces for a given organization

See terraform_cloud_organizations.sh to get a list of organization IDs
See terraform_cloud_varsets.sh to get a list of workspaces and their IDs


Output:

<id>    <name>
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<organization>]"

help_usage "$@"

#min_args 1 "$@"

org="${1:-${TERRAFORM_ORGANIZATION:-}}"

if [ -z "$org" ]; then
    usage "no terraform organization given and TERRAFORM_ORGANIZATION not set"
fi

# TODO: add pagination support
"$srcdir/terraform_cloud_api.sh" "/organizations/$org/workspaces" |
jq_debug_pipe_dump |
jq -r '.data[] | [.id, .attributes.name] | @tsv'

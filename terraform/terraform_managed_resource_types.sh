ধরে নিন, আপনি একটি কোম্পানিতে নতুন DevOps ইঞ্জিনিয়ার হিসেবে জয়েন করেছেন। সেখানে কয়েক বছর ধরে তৈরি করা বিশাল একটি Terraform রিপোজিটরি আছে, যার ভেতর শত শত ফোল্ডার এবং হাজার হাজার লাইনের কোড (*.tf ফাইল) রয়েছে।

সমস্যা:
আপনাকে যদি আপনার ম্যানেজার জিজ্ঞেস করে, "আমাদের এই প্রজেক্টে AWS-এর ঠিক কী কী সার্ভিস ব্যবহার করা হয়েছে তার একটি লিস্ট দাও", তবে ম্যানুয়ালি প্রতিটা ফাইল খুলে দেখা অসম্ভব। আবার terraform state চেক করতে গেলেও ক্লাউডের অ্যাক্সেস বা পারমিশন লাগবে, যা আপনার কাছে প্রথম দিন নাও থাকতে পারে।

সমাধান (এই স্ক্রিপ্টের কাজ):
আপনি শুধু এই স্ক্রিপ্টটি পুরো প্রজেক্টের টপ-লেভেল ফোল্ডারে রান করে দেবেন:

Bash
./script.sh
এটি কোনো ক্লাউড অ্যাক্সেস ছাড়াই, সম্পূর্ণ লোকালি আপনার কোড ফাইলগুলো পড়ে এক সেকেন্ডে নিচের মতো একটি পরিষ্কার লিস্ট দিয়ে দেবে:

Plaintext
aws_instance
aws_s3_bucket
aws_security_group
aws_vpc
এটি দেখে আপনি বা আপনার ম্যানেজার এক পলকেই বুঝে যাবেন যে এই প্রজেক্টের মাধ্যমে ক্লাউডে ঠিক কোন কোন সার্ভিস ম্যানেজ করা হচ্ছে।


#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2023-05-06 00:18:38 +0100 (Sat, 06 May 2023)
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
Quick Terraform code parser of the given or current directory tree to list all the resources types found in Terraform *.tf code files

Useful to give you a quick glance of what services you are managing. Usually you're want to run this at the top of your Terraform repo

Caveat: won't return anything from modules outside your current or given directory tree, or any resources created by external referenced modules
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<dir>]"

help_usage "$@"

#min_args 1 "$@"

dir="${1:-.}"

find "$dir" -type f -iname '*.tf' -print0 |
xargs -0 grep -hR '^[[:space:]]*resource' |
awk '/^[[:space:]]*resource[[:space:]]/{print $2}' |
sed 's/^"//; s/"$//' |
sort -u

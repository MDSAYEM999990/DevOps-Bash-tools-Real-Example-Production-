যখন আপনি Terraform বা Terragrunt দিয়ে বড় কোনো ইনফ্রাস্ট্রাকচার বা মাইক্রোসার্ভিস আর্কিটেকচার মেইনটেইন করেন, তখন আপনার প্রোজেক্টে হয়তো ৩০ থেকে ৪০টি আলাদা আলাদা ডিরেক্টরি 
(Folders) থাকে। প্রতিটা ফোল্ডারে যখন আপনি terraform init বা terragrunt init রান করেন, তখন ব্যাকগ্রাউন্ডে Terraform প্রতিটা ফোল্ডারের ভেতর .terraform/providers/ নামক জায়গায় 
নতুন করে ক্লাউড প্রোভাইডার প্লাগইন ডাউনলোড করে।ভয়াবহতা:এক একটি AWS প্রোভাইডারের সাইজ প্রায় ৬০০ মেগাবাইট (600MB)। এখন আপনার যদি ৩০টি মডিউল বা ফোল্ডার থাকে, আর সবগুলোতে 
যদি আলাদাভাবে একই প্লাগইন ডাউনলোড হয়, তবে:$$30 \times 600\text{ MB} = 18,000\text{ MB} \approx 18\text{ GB}$$অর্থাৎ, একই প্লাগইন বারবার ডাউনলোড হয়ে শুধু শুধু আপনার ১৮ জিবি 
হার্ডডিস্কের জায়গা দখল করে বসে থাকবে! এই স্ক্রিপ্টের লেখক নিজেই দেখিয়েছেন যে তাঁর একটি প্রোজেক্টেই ৩০ বার একই AWS প্রোভাইডার ডুপ্লিকেট হয়েছিল।সমাধান কী?Terraform-এর একটি ফিচার 
আছে যাকে বলে Plugin Cache। এটি অন করে দিলে সব ফোল্ডারের জন্য প্লাগইন সেন্ট্রাল একটি জায়গায় একবারই ডাউনলোড হয় এবং বাকি ফোল্ডারগুলো সেখান থেকে শুধু লিঙ্ক (Symlink) ব্যবহার করে।
ফলে ১৮ জিবির কাজ মাত্র ৬০০ মেগাবাইটে হয়ে যায়। এই স্ক্রিপ্টটি আপনাকে ঠিক সেই সমস্যাটাই ধরে দেয় যে আপনার ক্যাশ কনফিগার করা দরকার কিনা।


#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2025-03-11 03:28:53 +0800 (Tue, 11 Mar 2025)
#
#  https///github.com/HariSekhon/DevOps-Bash-tools
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
Finds duplicate Terraform providers and their sizes

Useful to find space wastage caused by using Terragrunt without configuring a unified Terraform Plugin Cache:

    https://developer.hashicorp.com/terraform/cli/config/config-file#provider-plugin-cache

    https://terragrunt.gruntwork.io/docs/features/provider-cache-server/

    https://github.com/gruntwork-io/terragrunt/issues/561

    https://github.com/gruntwork-io/terragrunt/issues/2920

For example, in a repo checkout for a single project, I had 30 x 600MB AWS provider

    30  597M  hashicorp/aws/5.80.0/darwin_arm64/terraform-provider-aws_v5.80.0_x5
    7   637M  hashicorp/aws/5.90.1/darwin_arm64/terraform-provider-aws_v5.90.1_x5
    4   637M  hashicorp/aws/5.90.0/darwin_arm64/terraform-provider-aws_v5.90.0_x5
    3   599M  hashicorp/aws/5.81.0/darwin_arm64/terraform-provider-aws_v5.81.0_x5
    2   593M  hashicorp/aws/5.79.0/darwin_arm64/terraform-provider-aws_v5.79.0_x5

Output format:

    <count>    <provider_size>    <provider>
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<dir>]"

help_usage "$@"

#min_args 1 "$@"

dir="${1:-.}"

#timestamp "Finding Terraform providers"
# slow way of finding duplicates
#providers="$(find "$dir" -type f -name 'terraform-provider-*' -exec md5sum {} \;)"
providers="$(find "$dir" -type f -name 'terraform-provider-*')"
#echo

if [ -z "$providers" ]; then
    die "ERROR: no Terraform providers found. Did you run this from a Terraform / Terragrunt working directory that has been used?"
fi

#timestamp "Ranking providers by duplication level"
#echo

strip_prefix(){
    sed '
        s|.*\.terraform/providers/||;
        s|registry.terraform.io/||;
    '
}

strip_prefix <<< "$providers" |
sort |
uniq -c |
sort -k1nr |
while read -r count filepath; do
    echo -n "$count "
    # head -n 1 is more reliable than grep -m 1 on some platforms (macOS BSD)
    filename="$(grep "$filepath" <<< "$providers" | head -n 1)"
    du -h "$filename" |
    awk '{printf $1" "}'
    strip_prefix <<< "$filename"
done |
column -t

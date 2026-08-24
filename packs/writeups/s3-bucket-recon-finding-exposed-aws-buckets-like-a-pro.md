---
title: 'S3 Bucket Recon: Finding Exposed AWS Buckets Like a Pro!'
subtitle: 'From Discovery to Exploitation: A Complete Guide to S3 Bucket Recon'
tags:
- Bug Bounty
- Bug Bounty Tips
- AWS
- Technology
- Amazon Web Services
published: '2025-02-26'
updated: '2025-09-13'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/s3-bucket-recon-finding-exposed-aws-buckets-like-a-pro-106be5ab9e1d
source_url: https://infosecwriteups.com/s3-bucket-recon-finding-exposed-aws-buckets-like-a-pro-106be5ab9e1d
---

# S3 Bucket Recon: Finding Exposed AWS Buckets Like a Pro!

*From Discovery to Exploitation: A Complete Guide to S3 Bucket Recon*

*Published Feb 26, 2025 · Updated Sep 13, 2025 · Free: No*

#### AWS RECON

#### A Step-by-Step Guide to Identifying and Exploiting Misconfigured AWS Buckets

### Introduction

Amazon S3 (Simple Storage Service) is one of the most widely used cloud storage solutions, but misconfigurations can lead to serious security vulnerabilities. In this guide we'll explore how to audit S3 environments, uncover exposed buckets, analyze permissions and mitigate security risks. Using AWS tools and open-source scanners you'll learn to identify vulnerabilities before they become threats.

#### **What is S3 Bucket Reconnaissance?**

S3 bucket reconnaissance refers to the process of identifying and investigating publicly accessible or misconfigured AWS S3 buckets that may expose sensitive data. Developer or Security professional can use these techniques to help organizations to secure their cloud storage.

#### **Table of Contents**

```markdown
1. Understanding AWS S3 Buckets
2. Manual Methods for Identifying S3 Buckets
3. Google Dorking for AWS S3 Buckets
4. Automating Google Dorking with DorkEye
5. Using S3Misconfig tool for Fast Bucket Enumeration
6. Finding S3 Buckets with HTTPX and Nuclei
7. Extracting S3 URLs from JavaScript Files
8. Using java2s3 tool to finding s3 urls in js files
9. Brute-Forcing S3 Bucket Names with LazyS3
10. Using Cewl + S3Scanner to find open buckets
11. Extracting S3 Buckets from GitHub Repositories
12. Websites for Public S3 Bucket Discovery
13. Finding Hidden S3 URLs with Extensions
14. AWS S3 Bucket Listing & File Management:
15. Exploiting Misconfigured Buckets
16. Securing S3 Buckets for companies
```

### Manual Methods for Identifying S3 Buckets

#### Using Browser URL Inspection:

One of the simplest ways to check if a website is hosted on AWS is by entering the following in the browser URL bar:

```perl
%c0
```


If you encounter an XML error the website is likely hosted on Amazon AWS. To verify further use browser extensions like Wappalyzer to check for AWS-related technologies.

### Checking the Source Code

Inspect the website source code and search for "s3" to find any hidden S3 bucket URLs. if you found any just open and check if there bucket listing is enabled.



### Google Dorking for AWS S3 Buckets

Google dorking helps uncover exposed S3 buckets. you can use the following dork to find open s3 buckets:

```vbnet
site:s3.amazonaws.com "target.com"
site:*.s3.amazonaws.com "target.com"
site:s3-external-1.amazonaws.com "target.com"
site:s3.dualstack.us-east-1.amazonaws.com "target.com"
site:amazonaws.com inurl:s3.amazonaws.com
site:s3.amazonaws.com intitle:"index of"
site:s3.amazonaws.com inurl:".s3.amazonaws.com/"
site:s3.amazonaws.com intitle:"index of" "bucket"

(site:*.s3.amazonaws.com OR site:*.s3-external-1.amazonaws.com OR site:*.s3.dualstack.us-east-1.amazonaws.com OR site:*.s3.ap-south-1.amazonaws.com) "target.com"
```

If bucket listing is enabled you'll be able to view the entire directory and its files. If you see an "Access Denied" message it means the bucket is private.

### Automating Google Dorking with DorkEye

DorkEye automates Google dorking making reconnaissance faster by quickly extracting multiple AWS URLs for analysis.


[**GitHub - BullsEye0/dorks-eye: Dorks Eye Google Hacking Dork Scraping and Searching Script. Dorks…**](https://github.com/BullsEye0/dorks-eye)
*Dorks Eye Google Hacking Dork Scraping and Searching Script. Dorks Eye is a script I made in python 3. With this tool…*

### Using S3Misconfig for Fast Bucket Enumeration

S3Misconfig scans a list of URLs for open S3 buckets with listing enabled and saves the results in a user friendly HTML format for easy review.


[**GitHub - Atharv834/S3BucketMisconf**](https://github.com/Atharv834/S3BucketMisconf)
*Contribute to Atharv834/S3BucketMisconf development by creating an account on GitHub.*

### Finding S3 Buckets with HTTPX and Nuclei

You can use the HTTPX command along with the Nuclei tool to quickly identify all S3 buckets across subdomains saving you significant time in recon.

```vbnet
using subfinder+HTTPX
subfinder -d target.com -all -silent | httpx-toolkit -sc -title -td | grep "Amazon S3"

Nuclei template:
subfinder -d target.com -all -silent | nuclei -t /home/coffinxp/.local/nuclei-templates/http/technologies/s3-detect.yaml
```



### Extracting S3 URLs from JavaScript Files

Next we'll use the Katana tool to download JavaScript files from target subdomains and extract S3 URLs using the following grep command:

```bash
katana -u https://site.com/ -d 5 -jc | grep '\.js$' | tee alljs.txt
cat alljs.txt | xargs -I {} curl -s {} | grep -oE 'http[s]?://[^"]*\.s3\.amazonaws\.com[^" ]*' | sort -u
```

[**GitHub - projectdiscovery/katana: A next-generation crawling and spidering framework.**](https://github.com/projectdiscovery/katana)
*A next-generation crawling and spidering framework. - projectdiscovery/katana*

### Using java2s3 tool to find s3 urls in js files

Alternatively you can use this powerful approach to extract all S3 URLs from JavaScript files of subdomains. First combine Subfinder and HTTPX to generate the final list of subdomains then run the java2s3 tool for extraction.

```bash
subfinder -d target.com -all -silent | httpx-toolkit -o file.txt
cat file.txt | grep -oP '(?<=https?:\/\/).*' >input.txt
python java2s3.py input.txt target.com output.txt
cat output3.txt | grep -E "S3 Buckets: \['[^]]+"
cat output.txt | grep -oP 'https?://[a-zA-Z0-9.-]*s3(\.dualstack)?\.ap-[a-z0-9-]+\.amazonaws\.com/[^\s"<>]+' | sort -u
cat output3.txt | grep -oP '([a-zA-Z0-9.-]+\.s3(\.dualstack)?\.[a-z0-9-]+\.amazonaws\.com)' | sort -u
```




after this you can use use the S3Misconfig tool to identify publicly accessible S3 buckets with listing enabled by sending all these s3 urls to the tool

[**GitHub - mexploit30/java2s3**](https://github.com/mexploit30/java2s3)
*Contribute to mexploit30/java2s3 development by creating an account on GitHub.*

### Brute-Forcing S3 Bucket with LazyS3

You can also use this LazyS3 tool — it's basically a brute force tool for AWS S3 buckets using different permutations. you can run the following command by specifying the target domain

```xml
ruby lazys3.rb <COMPANY>
```


[**GitHub - nahamsec/lazys3**](https://github.com/nahamsec/lazys3)
*Contribute to nahamsec/lazys3 development by creating an account on GitHub.*

### Using Cewl + S3Scanner to find open buckets

Next use the Cewl tool to generate a custom wordlist from the target domain. Then run S3Scanner with the list to identify valid and invalid S3 buckets. Finally use a grep command to filter valid buckets based on permissions and size and inspect their contents using the AWS CLI.

```perl
cewl https://site.com/ -d 3 -w file.txt

s3scanner -bucket-file file.txt -enumerate -threads 10 | grep -aE 'AllUsers: \[.*(READ|WRITE|FULL).*]'
```


[**GitHub - sa7mon/S3Scanner: Scan for misconfigured S3 buckets across S3-compatible APIs!**](https://github.com/sa7mon/S3Scanner)
*Scan for misconfigured S3 buckets across S3-compatible APIs! - sa7mon/S3Scanner*

### Extracting S3 Buckets from GitHub Repositories

Use GitHub dorks to find AmazonAWS results in public repositories. Check S3 URLs for bucket listings and verify access with AWS CLI. If you discover sensitive data report it to bug bounty programs.

```vbnet
org:target "amazonaws"
org:target "bucket_name"
org:target "aws_access_key"
org:target "aws_access_key_id"
org:target "aws_key"
org:target "aws_secret"
org:target "aws_secret_key"
org:target "S3_BUCKET"
```


### Websites for Public S3 Bucket Discovery

Use these websites to search for files in public AWS buckets by keyword. Download and inspect the contents and if you find any sensitive files report them responsibly:

> grayhatwarfare:

[**Public Buckets by GrayhatWarfare**](https://buckets.grayhatwarfare.com/)
*Edit description*

> osint.sh

[https://osint.sh/buckets/](https://osint.sh/buckets/)


### Finding Hidden S3 URLs with Extensions

The S3BucketList Chrome extension scans web pages for exposed S3 URLs helping researchers quickly identify misconfigured buckets without manually inspecting the source code


[**S3BucketList - Chrome Web Store**](https://chromewebstore.google.com/detail/s3bucketlist/anngjobjhcbancaaogmlcffohpmcniki?hl=en)
*Search, lists, and checks S3 Buckets found in network requests*

### AWS S3 Bucket Listing & File Management

Easily manage AWS S3 buckets with these AWS CLI commands. These commands help security researchers, penetration testers and cloud administrators list, copy, delete and download files for efficient storage management and security assessments.

#### Reading Files:

```perl
aws s3 ls s3://[bucketname] --no-sign-request
```

#### **Recursively List All Files in Human-Readable Format**

```perl
aws s3 ls s3://[bucketname] --no-sign-request --recursive --human-readable
```

#### To identify potentially sensitive files

```perl
aws s3 ls s3://[bucketname] --no-sign-request --recursive | grep -E '\.env|\.pem|\.key|\.json|\.yml|\.yaml|\.config|config\.php|\.ini|\.sql|\.db|\.log|\.backup|\.bkp|\.crt|\.cert|\.pfx|\.p12|\.keystore|id_rsa|id_dsa|\.passwd|\.htpasswd|\.htaccess|\.csv|\.xlsx|\.docx|\.pdf'
aws s3 ls s3://[bucketname] --no-sign-request --recursive | grep -E '\.(env|pem|key|json|yml|yaml|config|php|ini|sql|db|log|backup|bkp|crt|cert|pfx|p12|keystore|rsa|dsa|passwd|htpasswd|htaccess|csv|xlsx|xls|docx|doc|pdf|pptx|ppt|md|txt|bak|old|orig|swp|tar|zip|rar|7z|gz|tgz|enc|sh|ps1|bat|exe|dll|class|jar|war|jsp|asp|php|py|rb|cgi|pl|cfm|aspx|vb|vbs|c|cpp|h|cs|swift|go|rs|log|session|token|auth|access|secret|private|ssh|gpg|pgp|kdbx|wallet|dat|sqlite|ldb|ndjson|nd|out|pid|dump|tar\.gz|tar\.bz2|zipx|xz|bak\.gz)'
```

#### Copying Files:

```perl
aws s3 cp file.txt s3://[bucketname] --no-sign-request
```

#### Deleting Files:

```bash
aws s3 rm s3://[bucketname]/file.txt --no-sign-request
```

#### Downloading All Files:

```perl
aws s3 cp s3://[bucketname]/ ./ --recursive --no-sign-request
```


> Buckets with "Full Control" permission allow file uploads and deletions which could lead to security risks. Always follow responsible disclosure policies when reporting vulnerabilities.

### **Securing S3 Buckets**

Organizations should follow best practices to prevent unauthorized access:

- Enable bucket policies and restrict access.
- Disable public ACLs unless necessary.
- Monitor logs using AWS CloudTrail.
- Implement encryption for sensitive data.

**_You can also watch this video where I showed the complete practicle of this method:_**

console.log(&quot;[FREEDIUM] iframe workaround started&quot;);
}
if (!event.data || (typeof event.data != 'string')) {
return false;
}
var data;
try {
data = JSON.parse(event.data);
} catch (e) {
console.error(e);
return false;
}
var iframe = document.querySelector('iframe');
if (!iframe || !(data.type === 'MEASURE' || data.context === 'iframe.resize')) {
return false;
}
notifyResize(data.height || data.details.height);
}; window.addEventListener('message', handleMessage)</script><script defer src=&quot;https://static.cloudflareinsights.com/beacon.min.js/v833ccba57c9e4d2798f2e76cebdd09a11778172276447&quot; integrity=&quot;sha512-57MDmcccJXYtNnH+ZiBwzC4jb2rvgVCEokYN+L/nLlmO8rfYT/gIpW2A569iJ/3b+0UEasghjuZH/ma3wIs/EQ==&quot; data-cf-beacon='{&quot;version&quot;:&quot;2024.11.0&quot;,&quot;token&quot;:&quot;0b5f665943484354a59c39c6833f7078&quot;,&quot;server_timing&quot;:{&quot;name&quot;:{&quot;cfCacheStatus&quot;:true,&quot;cfEdge&quot;:true,&quot;cfExtPri&quot;:true,&quot;cfL4&quot;:true,&quot;cfOrigin&quot;:true,&quot;cfSpeedBrain&quot;:true},&quot;location_startswith&quot;:null}}' crossorigin=&quot;anonymous&quot;></script>

### Conclusion

S3 bucket reconnaissance is essential for ethical hackers and security professionals. Identifying and securing misconfigured buckets helps organizations strengthen their cloud security and prevent data leaks.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly_

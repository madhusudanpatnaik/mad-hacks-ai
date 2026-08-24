---
title: 'GitHub Recon: The Underrated Technique to Discover High-Impact Leaks in Bug Bounty'
subtitle: Master the Art of Finding API Keys, Credentials and Sensitive Data in Public Repositories
tags:
- Bug Bounty
- Cybersecurity
- Technology
- Programming
- Github
published: '2025-05-29'
updated: '2026-04-23'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/github-recon-the-underrated-technique-to-discover-high-impact-leaks-in-bug-bounty-c4069894389a
source_url: https://infosecwriteups.com/github-recon-the-underrated-technique-to-discover-high-impact-leaks-in-bug-bounty-c4069894389a
---

# GitHub Recon: The Underrated Technique to Discover High-Impact Leaks in Bug Bounty

*Master the Art of Finding API Keys, Credentials and Sensitive Data in Public Repositories*

*Published May 29, 2025 · Updated Apr 23, 2026 · Free: No*

#### GITHUB RECON

### Introduction

Reconnaissance is the foundation of any successful bug bounty journey and one of the most overlooked goldmines is GitHub. Developers often unknowingly push sensitive data into public repositories, giving ethical hackers a powerful vector to uncover secrets, tokens, credentials and much more.

In this article, I'll walk you through manual and automated techniques to extract valuable data from GitHub. We'll use filters, dorks and tools everything you need to perform impactful recon using only open-source intelligence (OSINT).

### Basic Search Tactics

Start by heading over to [GitHub.com](https://github.com) and typing your target domain along with a sensitive keyword in the search bar.

**_Example:_**

```bash
"example.com" password
```

This will show repositories and files containing the keyword "password" that are linked to the example.com domain.

### JSON-Formatted Keyword Searches

To make the results more relevant, format your keyword like a JSON key-value pair.

**_Example:_**


```json
"example.com" "password":
```

Why? Because secrets stored in JSON often follow a predictable key-value pattern. This helps filter out noise and lets you focus on the juicy stuff credentials, API keys and access tokens.

You'll immediately notice a smaller set of results but each is more precise, containing values like:

```json
"username": "admin",
"password": "supersecret123"
```

### Use `org:` Filter for Official Repositories

If your target has a public GitHub organization use the org: filter.

**_Example:_**

```vbnet
org:example "password":
```

This limits results to repositories officially owned by the organization. However many bug bounty programs don't use GitHub orgs so you'll still rely on general keyword searches for most targets.

### Custom GitHub Dorks for Recon

To save time use a custom GitHub dork with logical operators: AND,OR

**_Example:_**

```bash
"domain" AND ("api_key" OR "secret" OR "password" OR "access_token" OR "client_secret" OR "private_key" OR "AWS_SECRET_ACCESS_KEY" OR "DB_PASSWORD" OR "slack_token" OR "github_token" OR "BEGIN RSA PRIVATE KEY")
```

This dork pulls results that match any of these keywords. This way you won't need to search for each keyword separately. You'll get all relevant results at once.

### Filtering by Path, Language and File Type

During reconnaissance, filtering by **path**, **language** and **file type** helps narrow down valuable targets. Below are some common filters to use:

```vbnet
filename: Search by specific file names (e.g. filename:.env)
extension: Filter by file type (e.g. extension:json)
path: Search within specific directories (e.g. path:/config)
org: Limit results to an organization (e.g. org:my-company)
repo: Focus on a specific repository (e.g. repo:my-project)
```

#### 1. Filename: — Search by Specific File Name

```bash
filename:.env "DB_PASSWORD"
```

Finds all .env files containing the keyword DB_PASSWORD. .env files often include credentials, secrets and API keys.

#### 2. Extension: — Filter by File Type

```vbnet
extension:json "access_token"
```

Searches all .json files across GitHub that contain the string access_token. Great for finding exposed tokens in config files.

#### 3. path: — Search Within Specific Directories

```bash
path:/config filename:database.php       # Finds database.php inside any /config directory
path:/wp-config.php                      # Targets the WordPress config file
path:/src/secrets                        # Looks in typical config directories
path:/settings                           # Looks in typical settings directories
path:/.ssh                               # Searches hidden .ssh folder
path:/.git                               # Searches hidden .git folder
path:**/.env                             # Finds .env files in any nested directory
```


Use the path: filter to find files located in specific folders or subdirectories. This is useful for locating sensitive files commonly stored in predictable paths.

#### 4. repo: — Focus on a Specific Repository

```lua
repo:vercel/next.js filename:config.js
```

Limits search to the vercel/next.js repo and looks for config.js files. Great when you're auditing a specific open-source project.

### Bonus: Combine Filters for Maximum Precision

Find files that contain both "password" and "domain" keywords anywhere within a specific language, such as .php, .jsp or .asp.

```sql
"domain" language:PHP password
```

This dork searches for **PHP files** that contain both the word **"password"** and **"domain"** anywhere in the content. It's useful when you're looking for potential credentials or sensitive data related to your domain.

> **Note: Many of these credentials are committed by random developers. It's crucial to confirm if they belong to your target's assets before reporting.**

### Keyword Variations

Don't just search for "password." Try variations like:

```bash
password
passwd
pwd
pass
```

### Advanced Keyword Search (Highly Sensitive Keys & Tokens)

Focus on keywords that reveal critical secrets like API keys, passwords and private tokens commonly found in code and config files.

#### Authentication & Secrets

```vbnet
api_key
access_token
client_secret
auth_token
authorizationToken
x-api-key
secret
SECRET_KEY
secret_token
credentials
token
secure
```

#### Cloud Provider Secrets

```typescript
AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID
aws_access_key_id
aws_secret_key
aws_token
GCP_SECRET
gcloud_api_key
firebase_url
shodan_api_key
```

#### Database Credentials

```typescript
DB_PASSWORD
DATABASE_URL
db_password
db_pass
MYSQL_PASSWORD
POSTGRES_PASSWORD
mongo_uri
mongodb_password
```

#### SSH & Private Keys

```vbnet
BEGIN RSA PRIVATE KEY
BEGIN OPENSSH PRIVATE KEY
BEGIN PGP PRIVATE KEY BLOCK
id_rsa
private_key
pem private
key
```

#### Service-Specific Tokens

```typescript
slack_token
discord_token
github_token
gitlab_token
twilio_auth_token
mailgun
stripe_secret
SF_USERNAME salesforce
```

> ***You can explore more powerful keyword combinations in my GitHub repository here:***

[**payloads/github-dork.txt at main · coffinxp/payloads**](https://github.com/coffinxp/payloads/blob/main/github-dork.txt)
*Contribute to coffinxp/payloads development by creating an account on GitHub.*

### Validating API Keys — Keyhacks

To verify whether exposed API keys are working use the Keyhacks repository. It includes all commands and testing methods for over 50+ types of API keys.

[**GitHub - streaak/keyhacks: Keyhacks is a repository which shows quick ways in which API keys leaked…**](https://github.com/streaak/keyhacks)
*Keyhacks is a repository which shows quick ways in which API keys leaked by a bug bounty program can be checked to see…*

### Automation with GitGraber

Manual recon is great, but for mass scale use [GitGraber](https://github.com/hisxo/gitGraber) tool, Install GitGraber and run:

```bash
# Search for sensitive data related to the entire organization
python3 gitGraber.py -k wordlists/keywords.txt -q nasa.gov -s

# Search for sensitive data related strictly to the domain
python3 gitGraber.py -k wordlists/keywords.txt -q "nasa.gov" -s
```


It'll scrape and sort all keyword matches in seconds. Even better, you get direct URLs, timestamps and raw JSON preview.

### Using TruffleHog for Deep Secret Scanning

TruffleHog is another powerful tool for hunting secrets in code repositories. Here's how to use it:

```perl
# Scan a local Git repository
trufflehog git file:///home/user/my-repo

# Scan a public GitHub repository
trufflehog git https://github.com/username/repo.git

# Scan with filtering results to show only verified and unknown findings
trufflehog git https://github.com/trufflesecurity/test_keys --results=verified,unknown

# Scan and format output as JSON using jq for readability
trufflehog git https://github.com/trufflesecurity/test_keys --results=verified,unknown --json | jq

# Scan a GitHub repository and include issue and PR comments in the scan
trufflehog github --repo=https://github.com/trufflesecurity/test_keys --issue-comments --pr-comments

# Scan all repositories in a GitHub organization using a personal access token
trufflehog github --org=nasa --token=yourgithubtoken

# Scan a specific GitHub repository (basic usage)
trufflehog github --repo=https://github.com/username/repo
```



These trufflehog commands help detect exposed secrets (like API keys, credentials, tokens) in Git repositories. You can scan local repos, GitHub repositories or entire organizations. Additional flags allow filtering results, parsing JSON and scanning comments in issues and PRs for deeper coverage.

### Mass Hunting .git Directory Exposure

. **git directories** on public websites are another goldmine. Why? Because they store the entire source code history, including deleted but restorable files.

#### Using Nuclei private template

```bash
cat domains.txt | nuclei -t gitExposed.yaml
```


#### Find Exposed .git Repositories with httpx-toolkit

```bash
httpx-toolkit -l subs.txt -path /.git/ -mc 200
cat domains.txt | httpx-toolkit -sc -server -cl -path "/.git/" -mc 200 -location -ms "Index of" -probe
cat domains.txt | grep "SUCCESS" | gf urls | httpx-toolkit -sc -server -cl -path "/.git/" -mc 200 -location -ms "Index of" -probe
```


This httpx-toolkit command scans a list of domains for exposed .git/ directories. It:

- Probes the /.git/ path
- Filters responses with status code 200
- Matches content with **"Index of"**
- Shows response status code, server header, content length and redirect location

#### Instantly Detect Git Leaks with This Extension

Install the .git browser extension. it automatically alerts you if any site exposes its Git repository, helping you quickly spot misconfigurations and potential attack surfaces during recon


[**DotGit - Chrome Web Store**](https://chromewebstore.google.com/detail/dotgit/pampamgoihgcedonnphgehgondkhikel?hl=en)
*An extension for checking if .git is exposed in visited websites*

> 💡 **Tip: Even if a site returns a 403 Forbidden for /.git/ , don't give up—some Git files might still be accessible. Use tools like GitDumper to attempt extraction and reconstruction of the repository.**

### Dumping Git Repositories

**Next Step:** Once you've identified a valid .git/ folder using the methods above, it's time to dump the repository contents. Use tools like GitTools, git-dumper or git-extractor to recover exposed files and inspect the source code.

```bash
 ./gitdumper.sh  https://domain.com/.git/ outputdir

git-dumper https://domain.com/.git/ outputdir
```


[**GitHub - internetwache/GitTools: A repository with 3 tools for pwn'ing websites with .git…**](https://github.com/internetwache/GitTools)
*A repository with 3 tools for pwn'ing websites with .git repositories available - internetwache/GitTools*

[**GitHub - arthaud/git-dumper: A tool to dump a git repository from a website**](https://github.com/arthaud/git-dumper)
*A tool to dump a git repository from a website. Contribute to arthaud/git-dumper development by creating an account on…*

#### Restoring Deleted Files and File Structure Review

After dumping the .git folder the next step is to rebuild the full file structure. This helps uncover deleted files, sensitive data and historical changes that may still exist in the Git history.

Run the following commands to restore and inspect the repository:

```bash
cd output_dir
git status
git restore .
git checkout .
```

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
</body></html>"></iframe>

### Conclusion

GitHub recon and .git hunting double trouble for insecure developers. With the right keywords, tools and validation strategies, you can uncover serious vulnerabilities often before anyone else leading to high-impact findings and well-paid $bounties.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly_

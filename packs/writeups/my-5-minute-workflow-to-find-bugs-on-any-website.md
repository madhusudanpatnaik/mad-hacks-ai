---
title: My 5-Minute Workflow to Find Bugs on Any Website
subtitle: A step-by-step guide to my most effective, shortcut methods for bug bounty hunting.
tags:
- Bug Bounty
- Technology
- Penetration Testing
- Programming
- Hacking
published: '2025-09-27'
updated: '2025-11-26'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/my-5-minute-workflow-to-find-bugs-on-any-website-c20075320c96
source_url: https://infosecwriteups.com/my-5-minute-workflow-to-find-bugs-on-any-website-c20075320c96
---

# My 5-Minute Workflow to Find Bugs on Any Website

*A step-by-step guide to my most effective, shortcut methods for bug bounty hunting.*

*Published Sep 27, 2025 · Updated Nov 26, 2025 · Free: No*

### Introduction

Hi everyone, welcome back! Today, I'm going to show you the exact method I use to find bugs on almost any website in under five minutes. I'll show you exactly how I do it. I use a really fast shortcut that combines a few clever tricks to quickly understand a website and then I let automated tools do the hard work of scanning for bugs. It's all about working smart, not hard, so you can find the most important vulnerabilities without wasting any time.

#### In this walkthrough, I'll cover:

- How I use **Shodan** to quickly identify mass-scale CVE exposures.
- Scripts that uncover hidden inputs, forms and URLs.
- Automation workflows with **Nuclei, GF patterns, Uro** and other tools.
- Recon techniques with WaybakURLs, **AlienVault, URLScan, VirusTotal** and more.
- My own custom scripts like **Lost Uncover** and **LostFuzzer** to streamline scanning.

### Method 1: Mass Scanning with Shodan & Nuclei

This is my go-to method for finding recently disclosed CVEs at a massive scale. It's incredibly efficient for identifying low-hanging fruit across thousands of targets.

1. **Find Your Target CVE:** First, pick a CVE you want to hunt for. For this example, let's say we're looking for a specific vulnerability in a popular software.
2. **Shodan Dorking:** Head over to **Shodan** and use a specific search dork related to the product or CVE. Shodan will instantly show you all the internet-connected devices matching your query.


3. **Facet Analysis for IPs:** On the results page, click the "More" option to open the Facet Analysis tab. From there, select the "ip" option. This neatly organizes all the results by their IP address.


4. **Extract and Scan:** Now for the magic. I use a custom bookmarklet I wrote that automatically fetches all the IP addresses from the Shodan results and downloads them as a .txt file. Here is the that bookmarklet script.

#### for ip's:

```javascript
javascript:(function(){var ipElements=document.querySelectorAll('strong');var ips=[];ipElements.forEach(function(e){ips.push(e.innerHTML.replace(/["']/g,''))});var ipsString=ips.join('\n');var a=document.createElement('a');a.href='data:text/plain;charset=utf-8,'+encodeURIComponent(ipsString);a.download='ip.txt';document.body.appendChild(a);a.click();})();
```

#### for domains:

```javascript
javascript:(function(){var ipElements=document.querySelectorAll('strong'),ips=[],domains=[];ipElements.forEach(function(e){var t=e.innerHTML.replace(/['"]/g,'').trim();/^(\d{1,3}\.){3}\d{1,3}$/.test(t)?ips.push(t):/^(?!\d+\.)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(t)&&domains.push(t)});var dataString=%27IPs:\n%27+ips.join(%27\n%27)+%27\n\nDomains:\n%27+domains.join(%27\n%27),a=document.createElement(%27a%27);a.href=%27data:text/plain;charset=utf-8,%27+encodeURIComponent(dataString);a.download=%27domains.txt%27;document.body.appendChild(a);a.click();})();
```

You can also use **shef**, a lightweight command-line tool written in Go by our team. Shef integrates Facets into your terminal environment and operates without requiring an API key.

[**GitHub — 1hehaq/shef: bring shodan facets into your terminal without API key.**](https://github.com/1hehaq/shef)
*bring shodan facets into your terminal without API key. — 1hehaq/shef*

Once you have the file, you can feed it directly into **Nuclei** for automated scanning. Simply replace the tags or template name with the one relevant to your CVE. In minutes, Nuclei will scan the entire list and highlight any vulnerable hosts.

```bash
cat ip.txt | nuclei -tags grafana -bs 50 -c 50 -es info
```


### Method 2: Uncovering What's Hidden in Plain Sight

Developers often disable form inputs, buttons or hide entire sections of a page, thinking they are secure. This script helps you bypass those client-side restrictions.

```dart
javascript:(function(){document.querySelectorAll('[disabled],[readonly]').forEach(el=>{el.removeAttribute('disabled');el.removeAttribute('readonly');});document.querySelectorAll('[style*="display: none"]').forEach(el=>{el.style.display='block';});document.querySelectorAll('[style*="pointer-events: none"]').forEach(el=>{el.style.pointerEvents='auto';el.style.opacity='1';});alert('Disabled, readonly, and hidden elements are now active!');})();
```

I've integrated a handy script into my **Lost Uncover** tool that automatically finds and modifies these elements on a webpage:

```javascript
```

You can use this HTML file to test the script. Simply open the file and use the 'Lost Uncover → Unhide Element' option

```xml
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Bookmarklet Test Page</title>
  <style>
    body {
      background-color: black;
      color: #00ff88;
      font-family: monospace;
      padding: 20px;
    }
    input, button {
      font-family: monospace;
      margin-top: 5px;
      margin-bottom: 20px;
      padding: 5px;
    }
    .hidden {
      display: none;
    }
    .grayed {
      pointer-events: none;
      opacity: 0.4;
    }
  </style>
</head>
<body>
  <h1>Bookmarklet Test Page</h1>

  <h2>Disabled Input</h2>
  <label>Email (Disabled):<br>
    <input type="text" value="you@nowhere.com123" disabled>
  </label>

  <h2>Readonly Input</h2>
  <label>Username (Readonly):<br>
    <input type="text" value="readonly_user123" readonly>
  </label>

  <h2>Hidden Button</h2>
  <button class="hidden" id="secret-btn">Secret Admin Button</button>

  <h2>Grayed-Out Section</h2>
  <div class="grayed">Premium Content</div>
</body>
</html>
```


As you can see, after clicking 'Unhide Element,' it reveal Disabled Inputs, Readonly Inputs, Hidden Buttons, Grayed-Out Sections and similar elements.


You can also use this script to quickly **scan any website for URLs, endpoints, and hidden resources** directly from your browser.

#### In short, here's what it does:

- Opens a **floating, resizable panel** at the bottom of the page.
- Collects URLs from the page including <a>, <script>, <img>, <link>, <form> tags, inline HTML, CSS url() paths, and browser resource performance entries.
- **Scans external JavaScript files** to find more endpoints using regex.
- Lets you search/filter URLs, copy all URLs to clipboard, or export them as a .txt file.
- Can **unhide hidden or disabled elements** on the page for testing purposes.
- Supports a **domain-only filter** to focus on internal links.
- Shows **scan progress** and total URLs found.
- Can be **closed with Escape key** or by clicking ❌, aborting ongoing fetches.

By re-enabling these elements, you can often access forgotten or administrative functionalities that are still active on the backend. It's amazing what you can find just by poking around in features that were meant to be hidden.

### Method 3: My Automated Bug Hunting Toolkit: A Deep Dive into Each Tool

To really speed things up, I rely on a set of powerful scripts and tools that automate the most time-consuming parts of reconnaissance. Here's a look at the key players in my automation workflow.

### AlienVault OTX: The Foundation for Mass URL Discovery

This is where my main automation begins. The first step is to get a complete map of the target's web presence, and for that, I use a script that queries **AlienVault's Open Threat Exchange (OTX)**.

```bash
./alienvault.sh domain.com
```


[**scripts/alienvault.sh at main · coffinxp/scripts**](https://github.com/coffinxp/scripts/blob/main/alienvault.sh)
*Contribute to coffinxp/scripts development by creating an account on GitHub.*

Its superpower is its thoroughness. It digs deep and fetches every known URL associated with a domain, crawling through pages until it has a massive list. Once I have this raw data, I refine it to find the most interesting targets:

1. **Generate the URL list** using the AlienVault script.
2. Filter for interesting parameters using gf patterns (like gf xss or gf sqli).
3. Remove duplicates with a tool like uro.

The final command looks something like this, leaving me with a clean list of potentially vulnerable URLs ready for testing:

```bash
cat all_urls.txt | gf xss | uro > unique_xss_targets.txt
cat all_urls.txt | gf sqli | uro > unique_xss_targets.txt
cat all_urls.txt | gf idor | uro > unique_xss_targets.txt
cat all_urls.txt | gf ssrf | uro > unique_xss_targets.txt
cat all_urls.txt | gf redirect | uro > unique_xss_targets.txt
```

You can find all the gf patterns in my GitHub repository. Make sure to install the gf tool first before using them

[**GitHub - coffinxp/GFpattren**](https://github.com/coffinxp/GFpattren)
*Contribute to coffinxp/GFpattren development by creating an account on GitHub.*

[**GitHub - tomnomnom/gf: A wrapper around grep, to help you grep for things**](https://github.com/tomnomnom/gf)
*A wrapper around grep, to help you grep for things - tomnomnom/gf*

### LostFuzzer: Your Quick & Easy DAST Scanner

You can use my **LostFuzzer** script for a simple, direct approach. Provide a domain (or a list of domains) and it will automatically run a Nuclei DAST scan to find vulnerabilities. It's lightweight, easy to use, and delivers high-impact results with minimal effort. You Read more about this in my Medium article:

[**LostFuzzer: Passive URL Fuzzing & Nuclei DAST for Bug Hunters**](https://infosecwriteups.com/lostfuzzer-passive-url-fuzzing-nuclei-dast-for-bug-hunters-a33501b9563b)
*A Bash script for automated nuclei dast scanning by using passive urls*

### URLScan.io: Uncovering Hidden Subdomains and Endpoints

**URLScan.io** is another goldmine for reconnaissance, and using a script to automate queries is a huge time-saver. This tool is great for two main tasks:

- **Finding Subdomains:** You can run the script in "Subdomains" mode to get a list of all related subdomains. I often pipe this output directly to **HTTPX** to see which ones are live and what technology they're running.
- **Discovering More URLs:** In "URLs" mode, it fetches another unique set of URLs. You can add these to the list you got from AlienVault or scan them separately with Nuclei DAST.

```css
python urlscan.py -d redbull.com --mode urls
python urlscan.py -d redbull.com --mode subdomains
```


[**scripts/urlscan.py at main · coffinxp/scripts**](https://github.com/coffinxp/scripts/blob/main/urlscan.py)
*Contribute to coffinxp/scripts development by creating an account on GitHub.*

### VirusTotal Script: Mining for Digital Gold

This is one of my secret weapons for finding the kind of sensitive information that other tools often miss. Using a script written by **Orwa** that queries **VirusTotal**, you can uncover some incredible findings.

Because VirusTotal analyzes files and URLs submitted by users worldwide, its database sometimes contains exposed secrets related to your target. I have personally used this script to find:

- Email and password combinations.
- Internal API keys.
- Password reset tokens and other sensitive links

It's always worth a quick check, you never know what secrets might be hiding in plain sight, also make sure to add your three different virustotal api keys in the given script.

```bash
./virustotal.sh domain.com
```


[**scripts/virustotal.sh at main · coffinxp/scripts**](https://github.com/coffinxp/scripts/blob/main/virustotal.sh)
*Contribute to coffinxp/scripts development by creating an account on GitHub.*

### Waybackurls: The Engine of My Recon Workflow

This is my updated all‑in‑one URL‑gathering script, fast, flexible and integrates with other tools. It uses **waybackurls** as the core engine to pull historical URLs from sources like the Wayback Machine and Common Crawl. perfect for finding forgotten endpoints.

**Here are its key features:**

```bash
Usage: ./wayback.sh domain.com [-s] [-e] [-sc codes] [-scx codes]
Examples:
  ./wayback.sh example.com -s -sc 200
  ./wayback.sh example.com -sc 200,302,403
  ./wayback.sh example.com -scx 404,500
  ./wayback.sh example.com -e extensions only
```

- Subdomain Support (-s): Provide this flag to include all subdomains in the search, which is perfect for wildcard scope programs.
- Status Code Filtering (-sc & -scx): You can filter for specific status codes (like -sc 200 to only get live pages) or exclude codes (like -scx 404 to remove dead links).
- **Extension Filtering (-e):** Use this flag to retrieve only URLs with specific file types or extensions listed in the script.

The best part is that it's built for one-liners. You can chain it directly with other tools:

```bash
./wayback.sh example.com -s -sc 200 | gf xss
```


[**scripts/wayback.sh at main · coffinxp/scripts**](https://github.com/coffinxp/scripts/blob/main/wayback.sh)
*Contribute to coffinxp/scripts development by creating an account on GitHub.*

### Gospider: fast crawling & JS harvesting

Here's another fast crawler I use for site mapping, JS analysis and endpoint discovery. Lightweight and perfect for one-liners with jsleaks, lazyegg, gf patterns and nuclei, it can generate and verify links from JavaScript using LinkFinder, detect AWS S3 buckets from page sources and extract subdomains or hidden URLs. It also pulls data from the Wayback Machine, Common Crawl, VirusTotal and AlienVault. giving a complete view of your target's exposed assets for a fast, powerful recon workflow.

#### Basic commands:

```yaml
gospider -s https://example.com                      # Crawl the site and print discovered URLs/paths.
gospider -s https://example.com -a                   # Crawl the site and also gather URLs from 3rd-party sources
                                                      (Archive.org,CommonCrawl,VirusTotal,AlienVault).
gospider -s https://example.com -d 3                 # Crawl the site with recursion depth 3 (follow links up to 3 levels deep).
gospider -s https://example.com --subs               # Crawl the site and include discovered subdomains in the results.
gospider -s https://example.com --sitemap -d 2       # Try to parse sitemap.xml and crawl with max depth 2 (uses sitemap to find additional URLs).
gospider -s https://example.com -p http://127.0.0.1:8080  # Crawl the site but send requests through the specified HTTP proxy.
gospider -s https://example.com/upload/ -d 3 --whitelist "/upload/"  # Crawl only paths matching the whitelist “/upload/” up to depth 3 (limits scope).
```


#### Pro JS One‑Liners for Hunting Secrets:

```yaml
gospider -s https://example.com | grep -Eo 'https?://[^"'\''<>[:space:]]+' | sort -u
# Crawl domain, extract absolute URLs, then sort & dedupe.

gospider -s https://example.com -d 3 | grep '\.js$' | grep -Eo 'https?://[^"'\''<>[:space:]]+'
# Crawl to depth 3, keep .js URLs, extract absolute URLs.

gospider -s https://example.com | grep -Eo 'https?://[^"'\''<>[:space:]]+' | grep '\.js$' | jsleaks -s -k
# Find JS file URLs and scan them with jsleaks for possible secrets (jsleaks flags -s -k).

gospider -s https://example.com | grep -Eo 'https?://[^"'\''<>[:space:]]+' | grep '\.js$' | xargs -I{} bash -c 'echo -e "\ntarget : {}\n" && python lazyegg.py "{}" --js_urls --domains --ips --leaked_creds --local_storage'
# For each JS URL, print a header and run lazyegg to extract endpoints, domains, IPs, leaked creds and localStorage.

gospider -s https://example.com | grep -Eo 'https?://[^"'\''<>[:space:]]+' | grep '\.js$' | nuclei -t credentials-disclosure-all.yaml -c 30
# Feed discovered JS URLs into Nuclei using the credentials-disclosure-all template to hunt for exposed credentials/tokens.
```



As the screenshot shows, the endpoint no longer exists on the live server, yet it still appears in other passive sources. That's why I use the passive source flag. it helps uncover 404s and archived endpoints that active scans often miss.

[**GitHub - jaeles-project/gospider: Gospider - Fast web spider written in Go**](https://github.com/jaeles-project/gospider)
*Gospider - Fast web spider written in Go. Contribute to jaeles-project/gospider development by creating an account on…*

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

This is the exact workflow I use to find bugs on any website in under five minutes. With the right mix of Shodan searches, automation scripts and scanning tools, you'll uncover vulnerabilities faster than ever. Remember, the goal isn't just to find bugs. it's to report them responsibly and keep the internet a safer place.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly_

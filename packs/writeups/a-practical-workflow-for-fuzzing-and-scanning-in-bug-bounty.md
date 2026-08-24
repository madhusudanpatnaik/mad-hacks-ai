---
title: A Practical Workflow for Fuzzing and Scanning in Bug Bounty
subtitle: How to Systematically expand your attack surface, eliminate noise and find the bugs others miss.
tags:
- Bug Bounty
- Penetration Testing
- Technology
- Hacking
- Cybersecurity
published: '2026-03-26'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/a-practical-workflow-for-fuzzing-and-scanning-in-bug-bounty-64fa00ded29b
source_url: https://infosecwriteups.com/a-practical-workflow-for-fuzzing-and-scanning-in-bug-bounty-64fa00ded29b
---

# A Practical Workflow for Fuzzing and Scanning in Bug Bounty

*How to Systematically expand your attack surface, eliminate noise and find the bugs others miss.*

*Published Mar 26, 2026 · Free: No*

### Introduction

In **Bug Bounty** hunting, the line between landing a duplicate and uncovering a real critical issue usually comes down to how you perform reconnaissance. A lot of hunters stay on the surface. They scan the obvious assets, check the common ports and move on. But the valuable findings are often hidden in places most people ignore, like non standard ports, forgotten IP ranges and services that have been quietly running for years without attention.

In this guide, I'll walk you through a practical, multi stage approach to scanning and fuzzing that helps you expand your attack surface properly and spot opportunities others miss.

**_Recon Workflow_**

```javascript
   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌────────────────────┐    ┌──────────┐    ┌──────────┐
   │  CHAOS   │───▶│  HTTPX   │───▶│  NAABU  │───▶│  NMAP + PARSERS    │───▶│  NUCLEI  │───▶│   FFUF  │
   └──────────┘    └──────────┘    └──────────┘    └────────────────────┘    └──────────┘    └──────────┘
        │                │               │                   │                     │               │
        │                │               │                   │                     │               │
     [Gather]       [Live Check]    [Port Scan]         [Deep Scan]           [Vuln Scan]      [Fuzzing]

├───────────────────────────────────────────────────────────────────────────────
│ Phase 1: Subdomain Discovery
│
│   ├── Tool: Chaos
│   │     ├── Certificate transparency logs
│   │     ├── DNS PTR records
│   │     └── TLS scans
│   │
│   └── Broaden external attack surface
│
├───────────────────────────────────────────────────────────────────────────────
│ Phase 2: Alive Hosts and Deduplication
│
│   ├── Probing with HTTPX
│   │     ├── Identify live assets
│   │     └── Collect IP addresses
│   │
│   ├── IP Deduplication
│   │
│   └── CDN/WAF Filtering
│         ├── Avoid Cloudflare/Akamai/Fastly
│         └── Verify origin via page titles
│
├───────────────────────────────────────────────────────────────────────────────
│ Phase 3: Port Scanning
│
│   └── Tool: Naabu
│         ├── Top 100 ports
│         ├── Verify open status
│         └── Create baseline for scanning
│
├───────────────────────────────────────────────────────────────────────────────
│ Phase 4: Service Detection and Parsing
│
│   ├── Advanced Nmap Scan
│   │     ├── Software identification
│   │     ├── Version fingerprinting
│   │     └── NSE vulnerability scripts
│   │
│   └── Nmap Parsing
│         ├── Convert XML to HTML
│         ├── Host exposure summary
│         └── Identify low hanging fruit
│
├───────────────────────────────────────────────────────────────────────────────
│ Phase 5: Automated Vulnerability Scanning
│
│   └── Tool: Nuclei
│         ├── Known CVE templates
│         ├── Default credentials
│         ├── Misconfigurations
│         └── Exposed tokens
│
├───────────────────────────────────────────────────────────────────────────────
│ Phase 6: Content Discovery and Fuzzing
│
│   ├── Tool: FFUF
│   │     ├── Directory brute forcing
│   │     ├── Hidden backup files
│   │     └── Sensitive paths (/admin, .env)
│   │
│   └── Fuzzing Pro-Tips
│         ├── Analyze response size/word count
│         ├── Include non-standard ports
│         └── Investigate 403 Forbidden
│
└───────────────────────────────────────────────────────────────────────────────
```

### Phase 1: Subdomain Discovery with Chaos

The first step in any reconnaissance process is discovering as many subdomains as possible. Instead of depending only on active brute-forcing or managing multiple API keys from different providers, we start with **Chaos** a tool that collects subdomains from certificate transparency logs, DNS PTR records and TLS scans, then stores them in a continuously updated database.

This lets you gather a large set of known assets before you even send a single probe to the target.

```text
chaos -d redbull.com -o redbull.txt
```


After running Chaos, we end up with a raw list of roughly 3,000 subdomains. That immediately gives us a much broader view of the target's external attack surface

### Phase 2: Identifying Alive Hosts and Deduplication

A long list of subdomains means nothing if most of them don't resolve. Before moving forward, we have to separate the real, live assets from the dead entries. This step eliminates noise and lets you focus only on what actually respond and are worth testing.

#### Probing with HTTPX:

Next, we run the list through httpx to check which subdomains are actually alive. At the same time, we collect their corresponding IP addresses.


#### **IP Deduplication:**

Many subdomains resolve to the same backend server or load balancer. To avoid wasting time, we sort the IPs and remove duplicates so we only scan unique hosts.

```bash
 httpx-toolkit -l redbull.txt -ip -silent | sed -nE 's/.*\[([0-9.]+)\].*/\1/p' | sort -u >ip.txt
```

After cleaning the data, we're left with 379 unique IPs, a far more manageable and efficient list to work with.

> 📝Note: Before you scan or fuzz anything, check if the IP belongs to Cloudflare, Akamai or Fastly. Most of your collected IPs will. Scanning them is pointless you're hitting their edge servers, not the real origin. You'll also get your IP banned fast. so always use httpx with the -title flag to quickly see what the IP resolves to. If the title matches the actual website, it's likely the origin IP. If it shows generic CDN/WAF pages, it's not worth targeting.

### Phase 3: Port Scanning with Naabu

Scanning every port across thousands of subdomains would be slow and noisy. Instead, running Naabu against the unique IPs lets you identify verified open ports quickly and efficiently.

```css
naabu -l ip.txt -top-ports 100 -rate 1500 -verify -silent -o naabu.txt
```


this gives us a clean, verified list of open ports, so we are not wasting effort on filtered or closed services. Save this output, it becomes the baseline for deeper scanning.

### Phase 4: Advanced Service Detection & Nmap Parsing

Now that we have a clean list of IPs and open ports, the next step is to understand what is actually running behind them.

Using a custom automation script, we pass the Naabu results into a more in-depth Nmap scan that performs service detection, version fingerprinting, and NSE vulnerability script audits:

[**scripts/naabutonmap.py at main · coffinxp/scripts**](https://github.com/coffinxp/scripts/blob/main/naabutonmap.py)
*Contribute to coffinxp/scripts development by creating an account on GitHub.*

```css
python naabutonmap.py -i naabu.txt
```


- **Service Detection:** Identifying what software is running (e.g., Apache, Nginx, Redis).
- **Version Detection:** Finding specific software versions to look for known exploits.
- **Vulnerability Checks:** Running script-level audits.

#### Analyzing the Results

The scan produces several XML files, which are not exactly easy to review in raw form. To make the data readable, we run it through an Nmap parser. This converts the detailed XML output into a clean, structured HTML report that is much easier to analyze.

```bash
# Parse XML output into a readable HTML report
./nmap-parse-output /nmap-out/20260121_153728/nmap_out.xml html > scan.html
```


```bash
+--------------+-----------------------------------------------------------+
| Feature      | Benefit                                                   |
+--------------+-----------------------------------------------------------+
| Host Summary | Quickly see which IPs have the most exposure.             |
| Version Info | Identify "low hanging fruit" like outdated software.      |
| Visual Layout| Easily spot high-value attack surfaces for manual testing.|
+--------------+-----------------------------------------------------------+
```

[**GitHub - ernw/nmap-parse-output: Converts/manipulates/extracts data from a Nmap scan output.**](https://github.com/ernw/nmap-parse-output)
*Converts/manipulates/extracts data from a Nmap scan output. - ernw/nmap-parse-output*

### Phase 5: Automated Vulnerability Scanning with Nuclei

With a confirmed list of live IPs and open ports, we move into targeted vulnerability hunting. Nuclei works with thousands of templates covering known CVEs, default credentials, misconfigurations and exposed tokens.

```bash
# Scan live IPs for known CVEs
cat ip.txt | nuclei -tags cve -bs 200

# Scan all discovered ports (Naabu output)
cat naabu.txt | nuclei -tags cve -bs 200
```

By feeding it the Naabu output directly, we make sure every discovered port gets tested, not just the usual web ports like 80 and 443. This is important because many applications, admin panels, APIs or sensitive files and directories often hosted on non-standard ports, which are easy to miss if you only scan typical web services.

### Phase 6: Content Discovery and Fuzzing with FFUF

The final stage of reconnaissance is directory brute forcing or fuzzing, with ffuf.

Using a targeted wordlist, we look for hidden files, backup archives such as .bak or .zip and sensitive paths like /admin or exposed configuration files such as .env. This step often uncovers overlooked endpoints that can lead to serious findings.

```bash
ffuf -w ip.txt:SUB -w payloads/backup_files_only.txt:FILE -u https://SUB/FILE -mc 200 -rate 50  -fs 0 -c
ffuf -w naabu.txt:SUB -w payloads/backup_files_only.txt:FILE -u https://SUB/FILE -mc 200 -rate 50  -fs 0 -c
```


[**payloads/backup_files_only.txt at main · coffinxp/payloads**](https://github.com/coffinxp/payloads/blob/main/backup_files_only.txt)
*Contribute to coffinxp/payloads development by creating an account on GitHub.*

#### Pro-Tips for Fuzzing:

- Analyze the Responses: Don't just look at status codes. Pay attention to Response Size and Word Count. Sometimes a 200 OK is just a custom error page that happens to match the size of a real page.
- **Include Non-Standard Ports:** Use the Naabu port list within ffuf. Vulnerabilities are frequently found on internal services exposed on unusual ports.
- Don't Ignore 403s: A 403 Forbidden response often means you've found something sensitive. These endpoints are prime candidates for 403 bypass techniques.

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

This structured workflow turns random scanning into focused, high-value reconnaissance. By validating assets, mapping real services and then applying vulnerability and content discovery, you eliminate noise and gain a clear, prioritized attack surface. It saves time, scales well and puts you in a strong position for effective manual testing and real bug discoveries.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly._
